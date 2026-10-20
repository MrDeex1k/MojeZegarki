import CoreTransferable
import Foundation

/// A file representation lets us enforce the byte limit before Photos loads an entire original into memory.
struct ImportedImage: Transferable, Sendable {
    let data: Data
    static let maximumBytes = 20_000_000
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { file in
            ImportedImage(data: try read(file.file))
        }
    }
    static func read(_ url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
        guard data.count <= maximumBytes else { throw DocumentError.tooLarge }
        return data
    }
}
