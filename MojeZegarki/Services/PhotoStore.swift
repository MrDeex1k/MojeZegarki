import Foundation
import ImageIO
import UniformTypeIdentifiers

actor PhotoStore {
    let root: URL
    init(root: URL) { self.root = root }

    func importPhoto(_ data: Data) throws -> PhotoDraft {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = Self.downsample(source, pixels: 2400),
              let thumbnail = Self.downsample(source, pixels: 600) else { throw CollectionError.unreadablePhoto }
        let id = UUID()
        let staging = root.appendingPathComponent(".\(id.uuidString)", isDirectory: true)
        let destination = root.appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        do {
            let available = CGImageDestinationCopyTypeIdentifiers() as! [String]
            var filename = "photo.heic"
            let heicURL = staging.appendingPathComponent(filename)
            if !available.contains(UTType.heic.identifier) || !Self.encode(image, to: heicURL, type: .heic, quality: 0.82) {
                if FileManager.default.fileExists(atPath: heicURL.path) { try FileManager.default.removeItem(at: heicURL) }
                filename = "photo.jpg"
                guard Self.encode(image, to: staging.appendingPathComponent(filename), type: .jpeg, quality: 0.85) else {
                    throw CollectionError.fileAccess
                }
            }
            guard Self.encode(thumbnail, to: staging.appendingPathComponent("thumbnail.jpg"), type: .jpeg, quality: 0.8) else {
                throw CollectionError.fileAccess
            }
            for file in try FileManager.default.contentsOfDirectory(at: staging, includingPropertiesForKeys: nil) {
                try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: file.path)
            }
            try FileManager.default.moveItem(at: staging, to: destination)
            return PhotoDraft(id: id, filename: filename)
        } catch {
            try? FileManager.default.removeItem(at: staging)
            throw error
        }
    }

    func data(for photo: PhotoDraft, thumbnail: Bool = true) -> Data? {
        guard ["photo.heic", "photo.jpg"].contains(photo.filename) else { return nil }
        let url = root.appendingPathComponent(photo.id.uuidString)
            .appendingPathComponent(thumbnail ? "thumbnail.jpg" : photo.filename)
        return try? Data(contentsOf: url)
    }

    func remove(_ id: UUID) throws {
        let url = root.appendingPathComponent(id.uuidString)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    /// Called before presenting editors; also removes incomplete imports after interrupted launches.
    func removeUnreferenced(keeping ids: Set<UUID>) throws {
        guard FileManager.default.fileExists(atPath: root.path) else { return }
        for url in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
            let name = url.lastPathComponent
            if let id = UUID(uuidString: name), !ids.contains(id) { try FileManager.default.removeItem(at: url) }
            if name.hasPrefix("."), UUID(uuidString: String(name.dropFirst())) != nil { try FileManager.default.removeItem(at: url) }
        }
    }

    private static func downsample(_ source: CGImageSource, pixels: Int) -> CGImage? {
        CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: pixels,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary)
    }

    private static func encode(_ image: CGImage, to url: URL, type: UTType, quality: Double) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(destination)
    }
}
