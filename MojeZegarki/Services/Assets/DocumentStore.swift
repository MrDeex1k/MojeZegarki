import CryptoKit
import Foundation
import ImageIO
import OSLog
import PDFKit
import UniformTypeIdentifiers

actor DocumentStore {
    static let maximumBytes = BoundedFileReader.maximumBytes
    private var pendingDiscards: Set<UUID> = []
    let root: URL
    private let temporaryDirectory: TemporaryCollectionDirectory?
    init(root: URL, temporaryDirectory: TemporaryCollectionDirectory? = nil) {
        self.root = root
        self.temporaryDirectory = temporaryDirectory
    }

    /// Checks cancellation before requesting permission to read the provider’s URL.
    nonisolated func importFile(
        at url: URL, startAccess: @escaping @Sendable (URL) -> Bool = { $0.startAccessingSecurityScopedResource() }
    ) async throws -> DocumentAsset {
        try Task.checkCancellation()
        let read = CoordinatedDocumentRead()
        let bytes = try await withTaskCancellationHandler {
            try Task.checkCancellation()
            let scoped = startAccess(url)
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            var error: NSError?
            var result: Result<Data, Error>?
            read.coordinator.coordinate(readingItemAt: url, options: [], error: &error) { source in
                result = Result { try BoundedFileReader.read(source) }
            }
            try Task.checkCancellation()
            if let error { throw error }
            guard let result else { throw DocumentError.missingFile }
            return try result.get()
        } onCancel: {
            read.coordinator.cancel()
        }
        return try await importData(bytes)
    }

    /// Validates and writes a private copy, retrying cleanup of previously discarded imports.
    func importData(_ data: Data) throws -> DocumentAsset {
        guard data.count <= Self.maximumBytes else { throw DocumentError.tooLarge }
        try Task.checkCancellation()
        for id in pendingDiscards { discardUnattached(id) }
        let id = UUID()
        let staging = root.appendingPathComponent(".\(id.uuidString)", isDirectory: true)
        let destination = root.appendingPathComponent(id.uuidString, isDirectory: true)
        let filename: String
        let contentType: String
        let output: Data
        if data.starts(with: Data("%PDF-".utf8)) {
            guard let pdf = PDFDocument(data: data) else { throw DocumentError.unsupported }
            guard !pdf.isLocked else { throw DocumentError.protectedPDF }
            guard pdf.pageCount > 0 else { throw DocumentError.unsupported }
            filename = "document.pdf"
            contentType = UTType.pdf.identifier
            output = data  // Never recompress or rewrite an invoice PDF.
        } else {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                let image = CGImageSourceCreateThumbnailAtIndex(
                    source, 0,
                    [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: 4000,
                    ] as CFDictionary)
            else { throw DocumentError.unsupported }
            if let heic = Self.encode(image, type: .heic) {
                filename = "document.heic"
                contentType = UTType.heic.identifier
                output = heic
            } else if let jpeg = Self.encode(image, type: .jpeg) {
                filename = "document.jpg"
                contentType = UTType.jpeg.identifier
                output = jpeg
            } else {
                throw DocumentError.unsupported
            }
        }
        guard output.count <= Self.maximumBytes else { throw DocumentError.tooLarge }
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        try Task.checkCancellation()
        try StorageProtection.prepareDirectory(staging)
        do {
            try output.write(
                to: staging.appendingPathComponent(filename),
                options: [.atomic, .completeFileProtection])
            try Task.checkCancellation()
            try FileManager.default.moveItem(at: staging, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: staging)
            throw error
        }
        return DocumentAsset(
            id: id, filename: filename, contentType: contentType, fileSize: output.count,
            contentHash: hash)
    }

    func data(id: UUID, filename: String) throws -> Data {
        guard ["document.pdf", "document.heic", "document.jpg"].contains(filename) else {
            throw DocumentError.missingFile
        }
        do {
            return try Data(contentsOf: root.appendingPathComponent(id.uuidString).appendingPathComponent(filename))
        } catch { throw DocumentError.missingFile }
    }

    /// Removes a document directory, treating an already missing directory as success.
    func remove(_ id: UUID) throws {
        let url = root.appendingPathComponent(id.uuidString)
        do { try FileManager.default.removeItem(at: url) } catch CocoaError.fileNoSuchFile {}
    }

    /// Retries only known unattached files, so it is safe while other drafts are open.
    func discardUnattached(_ id: UUID) {
        do {
            try remove(id)
            pendingDiscards.remove(id)
        } catch {
            // The next import retries this ID. Startup orphan reconciliation covers relaunches.
            pendingDiscards.insert(id)
            Logger(subsystem: "pl.jakubbatycki.MojeZegarki", category: "Storage").error(
                "Unattached document cleanup failed: \(error, privacy: .private)")
        }
    }

    func removeUnreferenced(keeping ids: Set<UUID>) throws {
        guard FileManager.default.fileExists(atPath: root.path) else { return }
        for url in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
            let name = url.lastPathComponent
            if let id = UUID(uuidString: name), !ids.contains(id) { try FileManager.default.removeItem(at: url) }
            if name.hasPrefix("."), UUID(uuidString: String(name.dropFirst())) != nil {
                try FileManager.default.removeItem(at: url)
            }
        }
    }

    private static func encode(_ image: CGImage, type: UTType) -> Data? {
        let types = CGImageDestinationCopyTypeIdentifiers() as! [String]
        guard types.contains(type.identifier) else { return nil }
        let buffer = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(buffer, type.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(
            destination, image, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return buffer as Data
    }
}

// One task coordinates the read. The cancellation handler can call cancel() from another thread.
private final class CoordinatedDocumentRead: @unchecked Sendable {
    let coordinator = NSFileCoordinator()
}
