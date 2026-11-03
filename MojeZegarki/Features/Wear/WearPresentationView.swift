import SwiftUI

struct WearPresentationView: View {
    let store: CollectionStore
    let watch: Timepiece
    @Bindable var session: WearHistorySession
    let onClose: () -> Void

    var body: some View {
        if let editor = session.editor {
            WearEditorView(
                store: store, session: editor, onSaved: { session.savedCount = $0 },
                onClose: { session.editor = nil })
        } else {
            NavigationStack {
                WearView(store: store, watch: watch, session: session, presentsEditor: false)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done", systemImage: "checkmark", action: onClose)
                        }
                    }
            }
        }
    }
}
