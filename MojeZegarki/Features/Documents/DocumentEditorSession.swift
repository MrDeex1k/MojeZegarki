import Foundation
import Observation

@MainActor @Observable final class DocumentEditorSession: Identifiable {
    let id = UUID()
    let watch: Timepiece
    let asset: DocumentAsset?
    let document: DocumentItem?
    let original: DocumentDraft
    var draft: DocumentDraft
    let assets: DraftAssetSession
    var saving = false
    var error: String?

    /// Claims a new import before presentation so dismissal or failed presentation cannot orphan its file.
    init(
        watch: Timepiece, store: CollectionStore, asset: DocumentAsset? = nil,
        proposedName: String = "", document: DocumentItem? = nil
    ) {
        self.watch = watch
        self.asset = asset
        self.document = document
        original = DocumentDraft(
            name: document?.displayName ?? proposedName,
            kind: document.flatMap { DocumentKind(rawValue: $0.kindRaw) } ?? .purchase,
            date: document?.documentDate, notes: document?.notes ?? "")
        draft = original
        assets = DraftAssetSession { try await store.documentStore.remove($0) }
        if let asset { assets.claim(asset.id) }
    }
}
