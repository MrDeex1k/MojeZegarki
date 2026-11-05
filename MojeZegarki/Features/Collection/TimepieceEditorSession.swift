import Foundation
import Observation

@MainActor @Observable final class TimepieceEditorSession: Identifiable {
    let id = UUID()
    let watch: Timepiece?
    let wishlistItem: WishlistItem?
    let initial: TimepieceDraft
    var draft: TimepieceDraft
    let assets: DraftAssetSession
    var saving = false
    var error: String?

    init(store: CollectionStore, watch: Timepiece? = nil, wishlistItem: WishlistItem? = nil, locale: Locale = .current)
    {
        self.watch = watch
        self.wishlistItem = wishlistItem
        let initial =
            watch.map { TimepieceDraft(timepiece: $0, locale: locale) }
            ?? wishlistItem.map { WishlistDraft(item: $0, locale: locale).purchaseDraft }
            ?? TimepieceDraft(locale: locale)
        self.initial = initial
        draft = initial
        assets = DraftAssetSession { try await store.photoStore.remove($0) }
    }

    func save(in store: CollectionStore, locale: Locale) async -> Bool {
        guard !saving, !assets.isImporting, !assets.isFinished else { return false }
        saving = true
        error = nil
        defer { saving = false }
        do {
            if let watch { try store.requireManaged(watch) }
            if let wishlistItem { try store.requireManaged(wishlistItem) }
            let oldIDs = Set((watch?.sortedPhotos.map(\.id) ?? []) + (wishlistItem?.photoID.map { [$0] } ?? []))
            let retainedIDs = Set(draft.photos.map(\.id))
            try store.save(draft, editing: watch, moving: wishlistItem, locale: locale)
            await assets.commit(retaining: retainedIDs, replacing: oldIDs)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func importPhotos(_ sources: [@MainActor () async throws -> Data], from store: PhotoStore) {
        assets.run { [weak self] in
            for source in sources {
                do {
                    try Task.checkCancellation()
                    let bytes = try await source()
                    try Task.checkCancellation()
                    let photo = try await store.importPhoto(bytes)
                    guard let self else {
                        try? await store.remove(photo.id)
                        return
                    }
                    guard await assets.stage(photo.id) else { return }
                    draft.photos.append(photo)
                    if draft.mainPhotoID == nil { draft.mainPhotoID = photo.id }
                } catch is CancellationError { return } catch {
                    self?.error = String(
                        localized: "A photo could not be imported. Already imported photos are still available.")
                }
            }
        }
    }
}
