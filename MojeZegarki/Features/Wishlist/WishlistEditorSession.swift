import Foundation
import Observation

@MainActor @Observable final class WishlistEditorSession: Identifiable {
    let id = UUID()
    let item: WishlistItem?
    let initial: WishlistDraft
    var draft: WishlistDraft
    let assets: DraftAssetSession
    private(set) var saving = false
    var error: String?

    init(store: CollectionStore, item: WishlistItem? = nil, locale: Locale = .current) {
        self.item = item
        let initial = item.map { WishlistDraft(item: $0, locale: locale) } ?? WishlistDraft(locale: locale)
        self.initial = initial
        draft = initial
        assets = DraftAssetSession { try await store.photoStore.remove($0) }
    }

    func save(in store: CollectionStore, locale: Locale) async -> Bool {
        guard !saving, !assets.isFinished, !assets.isImporting else { return false }
        saving = true
        error = nil
        defer { saving = false }
        do {
            if let item { try store.requireManaged(item) }
            let oldIDs = Set(item?.photoID.map { [$0] } ?? [])
            let retainedIDs = Set(draft.photo.map { [$0.id] } ?? [])
            try store.saveWish(draft, editing: item, locale: locale)
            await assets.commit(retaining: retainedIDs, replacing: oldIDs)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func importPhoto(from store: PhotoStore, load: @escaping @MainActor () async throws -> Data) {
        assets.run { [weak self] in
            do {
                let data = try await load()
                try Task.checkCancellation()
                let imported = try await store.importPhoto(data)
                guard let self else {
                    try? await store.remove(imported.id)
                    return
                }
                guard await assets.stage(imported.id) else { return }
                draft.photo = imported
            } catch is CancellationError {} catch {
                self?.error = String(localized: "This photo could not be read. Choose another image.")
            }
        }
    }
}
