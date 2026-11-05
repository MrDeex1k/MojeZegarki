import Foundation
import SwiftData

extension CollectionStore {
    /// Editors own drafts and staged files. Only a successful explicit save changes the collection.
    @discardableResult
    func save(
        _ draft: TimepieceDraft, editing existing: Timepiece? = nil, moving wishlistItem: WishlistItem? = nil,
        locale: Locale = .current
    ) throws -> Timepiece {
        if let existing { try requireManaged(existing) }
        if let wishlistItem { try requireManaged(wishlistItem) }
        let price = try draft.validatedPrice(locale: locale)
        let watch = existing ?? Timepiece(brand: draft.brand.trimmed, modelName: draft.modelName.trimmed)
        beginChanges()
        if existing == nil { context.insert(watch) }
        watch.brand = draft.brand.trimmed
        watch.modelName = draft.modelName.trimmed
        watch.deviceKindRaw = draft.deviceKind?.rawValue
        watch.movementTypeRaw = draft.movementType?.rawValue
        watch.categoryIDs = draft.categories.map(\.rawValue).sorted()
        watch.referenceNumber = draft.referenceNumber.nilIfEmpty
        watch.serialNumber = draft.serialNumber.nilIfEmpty
        watch.purchaseDate = draft.purchaseDate
        watch.purchasePrice = price
        watch.currencyCode = price == nil ? nil : draft.currencyCode
        watch.seller = draft.seller.nilIfEmpty
        watch.notes = draft.notes.nilIfEmpty
        watch.statusRaw = draft.status.rawValue
        watch.updatedAt = Date()
        let oldPhotos = watch.photos ?? []
        let retainedIDs = Set(draft.photos.map(\.id))
        let photosByID = Dictionary(oldPhotos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        watch.photos = draft.photos.enumerated().map { index, item in
            let photo =
                photosByID[item.id]
                ?? TimepiecePhoto(id: item.id, filename: item.filename, position: index)
            if photo.modelContext == nil { context.insert(photo) }
            photo.position = index
            photo.timepiece = watch
            return photo
        }
        for photo in oldPhotos where !retainedIDs.contains(photo.id) {
            context.delete(photo)
        }
        watch.mainPhotoID =
            draft.photos.contains { $0.id == draft.mainPhotoID } ? draft.mainPhotoID : draft.photos.first?.id
        // Moving is one transaction: validation or a failed save must preserve the wish.
        if let wishlistItem { context.delete(wishlistItem) }
        try persistChanges { if existing != nil { watch.photos = oldPhotos } }
        return watch
    }

    func changeStatus(_ status: WatchStatus, for watch: Timepiece) throws {
        try requireManaged(watch)
        beginChanges()
        watch.statusRaw = status.rawValue
        watch.updatedAt = Date()
        try persistChanges()
    }

    func delete(_ watch: Timepiece) async throws {
        try requireManaged(watch)
        let photos = watch.sortedPhotos
        let photoIDs = photos.map(\.id)
        let documents = watch.documents ?? []
        let documentIDs = documents.map(\.id)
        let logs = watch.wearLogs ?? []
        beginChanges()
        // Explicit deletion also covers the iOS 17 SwiftData cascade behavior.
        for photo in photos { context.delete(photo) }
        for log in logs { context.delete(log) }
        for document in documents { context.delete(document) }
        context.delete(watch)
        try persistChanges {
            watch.photos = photos
            watch.wearLogs = logs
            watch.documents = documents
        }
        // Failed filesystem cleanup is retried at next startup by reconcileAssets().
        for id in photoIDs { try? await photoStore.remove(id) }
        for id in documentIDs { try? await documentStore.remove(id) }
    }

}
