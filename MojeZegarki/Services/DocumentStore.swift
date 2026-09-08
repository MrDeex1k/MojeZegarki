import Foundation
import CryptoKit
import PDFKit
import ImageIO
import UniformTypeIdentifiers

actor DocumentStore {
    static let maximumBytes = 20_000_000
    let root: URL
    init(root: URL) { self.root = root }

    func importFile(at url: URL) throws -> DocumentAsset {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var result: Result<Data, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            result = Result {
                let handle = try FileHandle(forReadingFrom: coordinatedURL)
                defer { try? handle.close() }
                // Bounded read protects against misleading file-size metadata from providers.
                return try handle.read(upToCount: Self.maximumBytes + 1) ?? Data()
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw DocumentError.missingFile }
        return try importData(result.get())
    }

    func importData(_ data: Data) throws -> DocumentAsset {
        guard data.count <= Self.maximumBytes else { throw DocumentError.tooLarge }
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
            output = data // Never recompress or rewrite an invoice PDF.
        } else {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 4000
                  ] as CFDictionary) else { throw DocumentError.unsupported }
            if let heic = Self.encode(image, type: .heic) {
                filename = "document.heic"; contentType = UTType.heic.identifier; output = heic
            } else if let jpeg = Self.encode(image, type: .jpeg) {
                filename = "document.jpg"; contentType = UTType.jpeg.identifier; output = jpeg
            } else { throw DocumentError.unsupported }
        }
        guard output.count <= Self.maximumBytes else { throw DocumentError.tooLarge }
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        do {
            try output.write(to: staging.appendingPathComponent(filename), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            try FileManager.default.moveItem(at: staging, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: staging)
            throw error
        }
        return DocumentAsset(id: id, filename: filename, contentType: contentType, fileSize: output.count,
                             contentHash: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
    }

    func data(id: UUID, filename: String) throws -> Data {
        guard ["document.pdf", "document.heic", "document.jpg"].contains(filename) else { throw DocumentError.missingFile }
        do { return try Data(contentsOf: root.appendingPathComponent(id.uuidString).appendingPathComponent(filename)) }
        catch { throw DocumentError.missingFile }
    }

    func remove(_ id: UUID) throws {
        let url = root.appendingPathComponent(id.uuidString)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    func removeUnreferenced(keeping ids: Set<UUID>) throws {
        guard FileManager.default.fileExists(atPath: root.path) else { return }
        for url in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
            let name = url.lastPathComponent
            if let id = UUID(uuidString: name), !ids.contains(id) { try FileManager.default.removeItem(at: url) }
            if name.hasPrefix("."), UUID(uuidString: String(name.dropFirst())) != nil { try FileManager.default.removeItem(at: url) }
        }
    }

    private static func encode(_ image: CGImage, type: UTType) -> Data? {
        let types = CGImageDestinationCopyTypeIdentifiers() as! [String]
        guard types.contains(type.identifier) else { return nil }
        let buffer = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(buffer, type.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return buffer as Data
    }
}
