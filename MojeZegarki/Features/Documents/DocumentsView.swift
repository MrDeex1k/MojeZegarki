import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct DocumentsView: View {
    let watch: Timepiece
    let store: CollectionStore
    let onClose: () -> Void
    @Query private var documents: [DocumentItem]
    @State private var choosingFile = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pending: DocumentAsset?
    @State private var pendingName = ""
    @State private var importing = false
    @State private var error: String?

    init(watch: Timepiece, store: CollectionStore, onClose: @escaping () -> Void) {
        self.watch = watch
        self.store = store
        self.onClose = onClose
        let watchID = watch.id
        _documents = Query(
            filter: #Predicate<DocumentItem> { $0.timepiece?.id == watchID },
            sort: \DocumentItem.createdAt,
            order: .reverse
        )
    }

    var body: some View {
        List {
            Section {
                Button("Import from Files", systemImage: "folder") { choosingFile = true }
                    .accessibilityIdentifier("documents.import")
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Choose document photo", systemImage: "photo")
                }
                if importing { ProgressView("Importing document…") }
            } footer: { Text("PDF or photo, up to 20 MB each. Files are copied to your private collection.") }
            .disabled(importing)

            if documents.isEmpty {
                ContentUnavailableView("No documents yet", systemImage: "doc.text", description: Text("Keep invoices and other documents with this watch."))
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(documents) { document in
                        NavigationLink {
                            DocumentPreviewView(document: document, store: store) {
                                error = $0
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: document.contentType == UTType.pdf.identifier ? "doc.text" : "photo")
                                    .font(.title2).foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(document.displayName).font(.headline)
                                    Text((DocumentKind(rawValue: document.kindRaw) ?? .other).title)
                                        .font(.subheadline).foregroundStyle(.secondary)
                                    if let date = document.documentDate {
                                        Text(date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .accessibilityIdentifier("document.\(document.id)")
                    }
                }
            }
        }
        .navigationTitle("Documents")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(importing)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Done", action: onClose).disabled(importing) }
        }
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.pdf, .image]) { result in
            switch result {
            case .success(let url):
                importing = true
                Task {
                    defer { importing = false }
                    do {
                        let asset = try await store.documentStore.importFile(at: url)
                        pendingName = url.deletingPathExtension().lastPathComponent
                        pending = asset
                    } catch { self.error = error.localizedDescription }
                }
            case .failure(let failure): error = failure.localizedDescription
            }
        }
        .onChange(of: selectedPhoto) { _, photo in
            guard let photo else { return }
            importing = true
            Task {
                defer { importing = false; selectedPhoto = nil }
                do {
                    guard let data = try await photo.loadTransferable(type: Data.self) else { throw DocumentError.unsupported }
                    let asset = try await store.documentStore.importData(data)
                    pendingName = String(localized: "Document")
                    pending = asset
                } catch { self.error = error.localizedDescription }
            }
        }
        .sheet(item: $pending) { asset in
            DocumentEditorView(watch: watch, store: store, asset: asset, proposedName: pendingName)
        }
        .appError($error)
    }
}

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
    @State private var committed = false
    @State private var error: String?

    init(watch: Timepiece, store: CollectionStore, asset: DocumentAsset? = nil, proposedName: String = "", document: DocumentItem? = nil) {
        self.watch = watch
        self.store = store
        self.asset = asset
        self.document = document
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
                Toggle("Add document date", isOn: Binding(get: { date != nil }, set: { date = $0 ? .now : nil }))
                if date != nil {
                    DatePicker("Document date", selection: Binding(get: { date ?? .now }, set: { date = $0 }), displayedComponents: .date)
                }
                TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...8)
            }
            .navigationTitle(document == nil ? Text("Add document") : Text("Edit document"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            if let document {
                                try store.updateDocument(document, name: name, kind: kind, date: date, notes: notes)
                            } else if let asset {
                                try store.attachDocument(asset, to: watch, name: name, kind: kind, date: date, notes: notes)
                            }
                            committed = true
                            dismiss()
                        } catch { self.error = error.localizedDescription }
                    }
                    .accessibilityIdentifier("document.save")
                }
            }
            .appError($error)
        }
        .onDisappear {
            if !committed, let asset { Task { try? await store.documentStore.remove(asset.id) } }
        }
    }
}
