import PhotosUI
import SwiftData
import SwiftUI
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
    @State private var preview: DocumentRoute?

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
            } footer: {
                Text("PDF or photo, up to 20 MB each. Files are copied to your private collection.")
            }
            .disabled(importing)

            if documents.isEmpty {
                ContentUnavailableView(
                    "No documents yet", systemImage: "doc.text",
                    description: Text("Keep invoices and other documents with this watch.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(documents) { document in
                        Button {
                            preview = DocumentRoute(id: document.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: document.contentType == UTType.pdf.identifier ? "doc.text" : "photo")
                                    .font(.title2).foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(document.displayName).font(.headline)
                                    Text((DocumentKind(rawValue: document.kindRaw) ?? .other).title)
                                        .font(.subheadline).foregroundStyle(Color.supportingText)
                                    if let date = document.documentDate {
                                        Text(date.formatted(date: .abbreviated, time: .omitted)).font(.caption)
                                            .foregroundStyle(Color.supportingText)
                                    }
                                }
                            }
                        }
                        .accessibilityIdentifier("document.\(document.id)")
                    }
                }
            }
        }
        .sheet(item: $preview) { route in
            NavigationStack {
                if let document = documents.first(where: { $0.id == route.id }) {
                    DocumentPreviewView(document: document, store: store, onClose: { preview = nil }) {
                        error = $0
                    }.toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { preview = nil } } }
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
                defer {
                    importing = false
                    selectedPhoto = nil
                }
                do {
                    guard let data = try await photo.loadTransferable(type: ImportedImage.self) else {
                        throw DocumentError.unsupported
                    }
                    let asset = try await store.documentStore.importData(data.data)
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
