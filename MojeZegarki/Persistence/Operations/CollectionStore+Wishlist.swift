import Foundation
import SwiftData

extension CollectionStore {
    struct WishMoveUndo {
        let originalID: UUID
        let position: Int
        let createdAt: Date
        let updatedAt: Date
        let draft: WishlistDraft
        let watchID: UUID
        let watchUpdatedAt: Date
    }

    func moveWish(_ item: WishlistItem) throws -> WishMoveUndo {
        try requireManaged(item)
        let locale = Locale(identifier: "en_US_POSIX")
        let draft = WishlistDraft(item: item, locale: locale)
        let id = item.id
        let createdAt = item.createdAt
        let updatedAt = item.updatedAt
        let position = item.position
        let watch = try save(draft.purchaseDraft, moving: item, locale: locale)
        return WishMoveUndo(
            originalID: id, position: position, createdAt: createdAt, updatedAt: updatedAt, draft: draft,
            watchID: watch.id, watchUpdatedAt: watch.updatedAt)
    }

    /// Undo only the unchanged quick conversion. Never discard subsequent edits or wear/document history.
    func undoWishMove(_ undo: WishMoveUndo) throws {
        let id = undo.watchID
        guard let watch = try context.fetch(FetchDescriptor<Timepiece>(predicate: #Predicate { $0.id == id })).first,
            watch.updatedAt == undo.watchUpdatedAt, (watch.wearLogs ?? []).isEmpty, (watch.documents ?? []).isEmpty
        else {
            throw WishlistError.changedAfterMove
        }
        let originalID = undo.originalID
        guard try context.fetchCount(FetchDescriptor<WishlistItem>(predicate: #Predicate { $0.id == originalID })) == 0
        else {
            throw WishlistError.changedAfterMove
        }
        let wish = WishlistItem(brand: undo.draft.brand, modelName: undo.draft.modelName)
        wish.id = originalID
        wish.createdAt = undo.createdAt
        wish.updatedAt = undo.updatedAt
        wish.targetPrice = undo.draft.price.nilIfEmpty
        wish.currencyCode = undo.draft.currencyCode.nilIfEmpty
        wish.url = undo.draft.url.nilIfEmpty
        wish.priority = undo.draft.priority.rawValue
        wish.position = undo.position
        wish.notes = undo.draft.notes.nilIfEmpty
        wish.photoID = undo.draft.photo?.id
        wish.photoFilename = undo.draft.photo?.filename
        beginChanges()
        context.insert(wish)
        let photos = watch.photos ?? []
        for photo in photos { context.delete(photo) }
        context.delete(watch)
        try persistChanges { watch.photos = photos }
    }

    @discardableResult
    func saveWish(
        _ draft: WishlistDraft, editing existing: WishlistItem? = nil, locale: Locale = .current,
        fetchPeers: ((Int) throws -> [WishlistItem])? = nil
    ) throws
        -> WishlistItem
    {
        if let existing { try requireManaged(existing) }
        let price = try draft.purchaseDraft.validatedPrice(locale: locale)
        let url = try draft.validatedURL()
        let position: Int
        if existing == nil || existing?.priority != draft.priority.rawValue {
            let priority = draft.priority.rawValue
            let lowestPosition: Int?
            if let fetchPeers {
                lowestPosition = try fetchPeers(priority).filter { $0.id != existing?.id }.map(\.position).min()
            } else {
                let excludedID = existing?.id ?? UUID()
                var query = FetchDescriptor<WishlistItem>(
                    predicate: #Predicate { $0.priority == priority && $0.id != excludedID },
                    sortBy: [SortDescriptor(\.position)])
                query.fetchLimit = 1
                lowestPosition = try context.fetch(query).first?.position
            }
            position = (lowestPosition ?? 0) - 1
        } else {
            position = existing?.position ?? 0
        }
        let item = existing ?? WishlistItem(brand: draft.brand.trimmed, modelName: draft.modelName.trimmed)
        beginChanges()
        if existing == nil { context.insert(item) }
        item.brand = draft.brand.trimmed
        item.modelName = draft.modelName.trimmed
        item.targetPrice = price
        item.currencyCode = price == nil ? nil : draft.currencyCode
        item.url = url
        item.position = position
        item.priority = draft.priority.rawValue
        item.notes = draft.notes.nilIfEmpty
        item.photoID = draft.photo?.id
        item.photoFilename = draft.photo?.filename
        item.updatedAt = .now
        try persistChanges()
        return item
    }

    /// Only a complete priority group can be reordered; filtered lists cannot hide peers.
    func reorderWishes(_ orderedIDs: [UUID], priority: WishlistPriority) throws {
        let rawPriority = priority.rawValue
        let peers = try context.fetch(
            FetchDescriptor<WishlistItem>(predicate: #Predicate { $0.priority == rawPriority }))
        guard orderedIDs.count == peers.count, Set(orderedIDs) == Set(peers.map(\.id)) else {
            throw WishlistError.invalidOrder
        }
        let byID = Dictionary(uniqueKeysWithValues: peers.map { ($0.id, $0) })
        beginChanges()
        for (position, id) in orderedIDs.enumerated() {
            byID[id]?.position = position
        }
        try persistChanges()
    }

    func deleteWish(_ item: WishlistItem) async throws {
        try requireManaged(item)
        let photoID = item.photoID
        beginChanges()
        context.delete(item)
        try persistChanges()
        if let photoID { try? await photoStore.remove(photoID) }
    }

}
