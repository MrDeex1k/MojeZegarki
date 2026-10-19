import SwiftUI

struct DocumentEditorView: View {
    let watch: Timepiece
    let store: CollectionStore
    var asset: DocumentAsset?
    var document: DocumentItem?
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var kind: DocumentKind
    @State private var date: Date?
    @State private var notes: String
    private let original: DocumentDraft
    @State private var discarding = false
    @State private var assets: DraftAssetSession
    @State private var error: String?
    @State private var saving = false

    init(
        watch: Timepiece, store: CollectionStore, asset: DocumentAsset? = nil, proposedName: String = "",
        document: DocumentItem? = nil
    ) {
        self.watch = watch
        self.store = store
        self.asset = asset
        _assets = State(
            initialValue: DraftAssetSession {
                try await store.documentStore.remove($0)
            })
        self.document = document
        original = DocumentDraft(
            name: document?.displayName ?? proposedName,
            kind: document.flatMap { DocumentKind(rawValue: $0.kindRaw) } ?? .purchase, date: document?.documentDate,
            notes: document?.notes ?? "")
        _name = State(initialValue: document?.displayName ?? proposedName)
        _kind = State(initialValue: document.flatMap { DocumentKind(rawValue: $0.kindRaw) } ?? .purchase)
        _date = State(initialValue: document?.documentDate)
        _notes = State(initialValue: document?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Document name", text: $name).accessibilityIdentifier("document.name")
                Picker("Document type", selection: $kind) {
                    ForEach(DocumentKind.allCases) { Text($0.title).tag($0) }
                }
                OptionalDateField(toggleTitle: "Add document date", dateTitle: "Document date", selection: $date)
                TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...8)
            }
            .disabled(saving)
            .navigationTitle(document == nil ? Text("Add document") : Text("Edit document"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if dirty { discarding = true } else { dismiss() } }.tint(Color(uiColor: .label))
                        .disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !saving else { return }
                        saving = true
                        do {
                            if let document {
                                try store.updateDocument(document, name: name, kind: kind, date: date, notes: notes)
                            } else if let asset {
                                try store.attachDocument(
                                    asset, to: watch, name: name, kind: kind, date: date, notes: notes)
                            }
                            Task {
                                await assets.commit(retaining: Set(asset.map { [$0.id] } ?? []))
                                saving = false
                                dismiss()
                            }
                        } catch {
                            saving = false
                            self.error = error.localizedDescription
                        }
                    }
                    .disabled(saving)
                    .accessibilityIdentifier("document.save")
                }
            }
            .interactiveDismissDisabled(dirty || saving)
            .discardChangesConfirmation(isPresented: $discarding) { dismiss() }
            .appError($error)
            .onAppear { if let asset { assets.claim(asset.id) } }
        }
    }
    private var dirty: Bool { original != DocumentDraft(name: name, kind: kind, date: date, notes: notes) }
}
