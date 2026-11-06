import SwiftUI

struct DocumentEditorView: View {
    let watch: Timepiece
    let store: CollectionStore
    var asset: DocumentAsset?
    var document: DocumentItem?
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: DocumentEditorSession
    @State private var discarding = false
    private var assets: DraftAssetSession { session.assets }
    private var saving: Bool {
        get { session.saving }
        nonmutating set { session.saving = newValue }
    }

    init(store: CollectionStore, session: DocumentEditorSession) {
        self.store = store
        self.session = session
        watch = session.watch
        asset = session.asset
        document = session.document
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Document name", text: $session.draft.name).accessibilityIdentifier("document.name")
                Picker("Document type", selection: $session.draft.kind) {
                    ForEach(DocumentKind.allCases) { Text($0.title).tag($0) }
                }
                OptionalDateField(
                    toggleTitle: "Add document date", dateTitle: "Document date", selection: $session.draft.date)
                TextField("Notes", text: $session.draft.notes, axis: .vertical).lineLimit(3...8)
            }
            .disabled(saving)
            .navigationTitle(document == nil ? Text("Add document") : Text("Edit document"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { if dirty { discarding = true } else { dismiss() } }.tint(
                        Color(uiColor: .label)
                    )
                    .disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        guard !saving, !assets.isFinished else { return }
                        saving = true
                        do {
                            if let document {
                                try store.updateDocument(
                                    document, name: session.draft.name, kind: session.draft.kind,
                                    date: session.draft.date, notes: session.draft.notes)
                            } else if let asset {
                                try store.attachDocument(
                                    asset, to: watch, name: session.draft.name, kind: session.draft.kind,
                                    date: session.draft.date, notes: session.draft.notes)
                            }
                            Task {
                                await assets.commit(retaining: Set(asset.map { [$0.id] } ?? []))
                                saving = false
                                dismiss()
                            }
                        } catch {
                            saving = false
                            session.error = error.localizedDescription
                        }
                    }
                    .disabled(saving)
                    .accessibilityIdentifier("document.save")
                }
            }
            .interactiveDismissDisabled(dirty || saving)
            .discardChangesConfirmation(isPresented: $discarding) { dismiss() }
            .appError($session.error)
        }
    }
    private var dirty: Bool { session.original != session.draft }
}
