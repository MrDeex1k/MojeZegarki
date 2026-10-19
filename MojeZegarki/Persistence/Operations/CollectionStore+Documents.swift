import Foundation
import SwiftData

extension CollectionStore {
    @discardableResult
    func attachDocument(
        _ asset: DocumentAsset, to watch: Timepiece, name: String, kind: DocumentKind, date: Date?, notes: String
    ) throws -> DocumentItem {
        guard watch.modelContext != nil, !watch.isDeleted else { throw WearError.missingWatch }
        let watchID = watch.id
        let hash = asset.contentHash
        let matches = try context.fetch(
            FetchDescriptor<DocumentItem>(
                predicate: #Predicate { $0.timepiece?.id == watchID && $0.contentHash == hash }))
        guard matches.isEmpty else { throw DocumentError.duplicate }
        let document = DocumentItem(
            asset: asset, name: name.nilIfEmpty ?? String(localized: "Document"), timepiece: watch)
        context.insert(document)
        document.kindRaw = kind.rawValue
        document.documentDate = date
        document.notes = notes.nilIfEmpty
        try persistChanges()
        return document
    }

    func updateDocument(_ document: DocumentItem, name: String, kind: DocumentKind, date: Date?, notes: String) throws {
        document.displayName = name.nilIfEmpty ?? String(localized: "Document")
        document.kindRaw = kind.rawValue
        document.documentDate = date
        document.notes = notes.nilIfEmpty
        try persistChanges()
    }

    func deleteDocument(_ document: DocumentItem) async throws {
        let id = document.id
        context.delete(document)
        try persistChanges()
        try? await documentStore.remove(id)
    }

}
