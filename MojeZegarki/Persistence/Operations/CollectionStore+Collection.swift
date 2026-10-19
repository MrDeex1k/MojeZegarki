import Foundation
import SwiftData

extension CollectionStore {
    /// Editors own drafts and staged files. Only a successful explicit save changes the collection.
    @discardableResult
    func save(
        _ draft: TimepieceDraft, editing existing: Timepiece? = nil, moving wishlistItem: WishlistItem? = nil,
        locale: Locale = .current
    ) throws -> Timepiece {
        let price = try draft.validatedPrice(locale: locale)
        let watch = existing ?? Timepiece(brand: draft.brand.trimmed, modelName: draft.modelName.trimmed)
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
        for photo in oldPhotos where !draft.photos.contains(where: { $0.id == photo.id }) {
            context.delete(photo)
        }
        watch.photos = draft.photos.enumerated().map { index, item in
            let photo =
                oldPhotos.first { $0.id == item.id }
                ?? TimepiecePhoto(id: item.id, filename: item.filename, position: index)
            photo.position = index
            photo.timepiece = watch
            return photo
        }
        watch.mainPhotoID =
            draft.photos.contains { $0.id == draft.mainPhotoID } ? draft.mainPhotoID : draft.photos.first?.id
        // Moving is one transaction: validation or a failed save must preserve the wish.
        if let wishlistItem { context.delete(wishlistItem) }
        do { try context.save() } catch {
            context.rollback()
            throw CollectionError.saveFailed
        }
        return watch
    }

    func changeStatus(_ status: WatchStatus, for watch: Timepiece) throws {
        watch.statusRaw = status.rawValue
        watch.updatedAt = Date()
        do { try context.save() } catch {
            context.rollback()
            throw CollectionError.saveFailed
        }
    }

    func delete(_ watch: Timepiece) async throws {
        let photos = watch.sortedPhotos
        let photoIDs = photos.map(\.id)
        let documents = watch.documents ?? []
        let documentIDs = documents.map(\.id)
        // Explicit deletion also covers the iOS 17 SwiftData cascade behavior.
        for photo in photos { context.delete(photo) }
        for log in watch.wearLogs ?? [] { context.delete(log) }
        for document in documents { context.delete(document) }
        context.delete(watch)
        do { try context.save() } catch {
            context.rollback()
            throw CollectionError.saveFailed
        }
        // Failed filesystem cleanup is retried at next startup by reconcileAssets().
        for id in photoIDs { try? await photoStore.remove(id) }
        for id in documentIDs { try? await documentStore.remove(id) }
    }

}
