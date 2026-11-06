import Foundation
import SwiftData

extension CollectionStore {
    /// Attaches an imported file unless the same watch already has a document with its content hash.
    @discardableResult
    func attachDocument(
        _ asset: DocumentAsset, to watch: Timepiece, name: String, kind: DocumentKind, date: Date?, notes: String
    ) throws -> DocumentItem {
        try requireManaged(watch)
        let watchID = watch.id
        let hash = asset.contentHash
        var query = FetchDescriptor<DocumentItem>(
            predicate: #Predicate { $0.timepiece?.id == watchID && $0.contentHash == hash })
        query.fetchLimit = 1
        let matches = try context.fetch(query)
        guard matches.isEmpty else { throw DocumentError.duplicate }
        let document = DocumentItem(
            asset: asset, name: name.nilIfEmpty ?? String(localized: "Document"), timepiece: nil)
        beginChanges()
        context.insert(document)
        document.timepiece = watch
        document.kindRaw = kind.rawValue
        document.documentDate = date
        document.notes = notes.nilIfEmpty
        try persistChanges()
        return document
    }

    /// Updates document metadata while keeping the existing file reference.
    func updateDocument(_ document: DocumentItem, name: String, kind: DocumentKind, date: Date?, notes: String) throws {
        try requireManaged(document)
        beginChanges()
        document.displayName = name.nilIfEmpty ?? String(localized: "Document")
        document.kindRaw = kind.rawValue
        document.documentDate = date
        document.notes = notes.nilIfEmpty
        try persistChanges()
    }

    /// Commits record removal before deleting the document file.
    func deleteDocument(_ document: DocumentItem) async throws {
        try requireManaged(document)
        let id = document.id
        let watch = document.timepiece
        let documents = watch?.documents
        beginChanges()
        context.delete(document)
        try persistChanges { watch?.documents = documents }
        try? await documentStore.remove(id)
    }

}
