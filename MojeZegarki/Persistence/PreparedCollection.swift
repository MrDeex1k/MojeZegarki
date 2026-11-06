import Foundation
import SwiftData

struct PreparedCollection: Sendable {
    let root: URL
    let container: ModelContainer
    let temporaryDirectory: TemporaryCollectionDirectory?
}

/// The in-memory collection and its asset actors share ownership of this directory.
final class TemporaryCollectionDirectory: Sendable {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
        "CollectionPreview-\(UUID())", isDirectory: true)

    deinit { try? FileManager.default.removeItem(at: url) }
}
