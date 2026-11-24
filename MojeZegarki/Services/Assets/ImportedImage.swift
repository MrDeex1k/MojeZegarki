import CoreTransferable
import Foundation

/// A file representation lets us enforce the byte limit before Photos loads an entire original into memory.
struct ImportedImage: Transferable, Sendable {
    let data: Data
    static let maximumBytes = BoundedFileReader.maximumBytes
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { file in
            ImportedImage(data: try read(file.file))
        }
    }
    static func read(_ url: URL) throws -> Data { try BoundedFileReader.read(url) }
}

enum BoundedFileReader {
    static let maximumBytes = 20_000_000

    static func read(_ url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        return try readChunks { try handle.read(upToCount: $0) }
    }

    static func readChunks(_ read: (Int) throws -> Data?) throws -> Data {
        var data = Data()
        while true {
            try Task.checkCancellation()
            guard let chunk = try read(min(65_536, maximumBytes - data.count + 1)), !chunk.isEmpty else { break }
            guard chunk.count <= maximumBytes - data.count else { throw DocumentError.tooLarge }
            data.append(chunk)
        }
        return data
    }
}
