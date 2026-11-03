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

    init(store: CollectionStore, watch: Timepiece? = nil, wishlistItem: WishlistItem? = nil) {
        self.watch = watch
        self.wishlistItem = wishlistItem
        let initial =
            watch.map { TimepieceDraft(timepiece: $0) }
            ?? wishlistItem.map { WishlistDraft(item: $0).purchaseDraft } ?? TimepieceDraft()
        self.initial = initial
        draft = initial
        assets = DraftAssetSession { try await store.photoStore.remove($0) }
    }
}
