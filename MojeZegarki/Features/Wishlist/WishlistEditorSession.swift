import Foundation
import Observation

@MainActor @Observable final class WishlistEditorSession: Identifiable {
    let id = UUID()
    let item: WishlistItem?
    let initial: WishlistDraft
    var draft: WishlistDraft
    let assets: DraftAssetSession
    var saving = false
    var error: String?

    init(store: CollectionStore, item: WishlistItem? = nil) {
        self.item = item
        let initial = item.map { WishlistDraft(item: $0) } ?? WishlistDraft()
        self.initial = initial
        draft = initial
        assets = DraftAssetSession { try await store.photoStore.remove($0) }
    }
}
