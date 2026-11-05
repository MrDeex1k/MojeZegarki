import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DocumentsView: View {
    private struct ImportRequest: Identifiable {
        enum Source {
            case file(URL)
            case photo(PhotosPickerItem)
        }

        let id = UUID()
        let source: Source
    }

    let watch: Timepiece
    let store: CollectionStore
    let onClose: () -> Void
    @Query private var documents: [DocumentItem]
    @State private var choosingFile = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pending: DocumentEditorSession?
    @State private var importRequest: ImportRequest?
    @State private var error: String?
    @State private var preview: DocumentRoute?
    private var importing: Bool { importRequest != nil }

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
                    .disabled(importing)
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Choose document photo", systemImage: "photo")
                }
                .disabled(importing)
                if importing {
                    ProgressView("Importing document…")
                    Button("Stop importing") { importRequest = nil }
                }
            } footer: {
                Text("PDF or photo, up to 20 MB each. Files are copied to your private collection.")
            }

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
                                    .font(.title2).foregroundStyle(.tint).accessibilityHidden(true)
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
                        .disabled(importing)
                    }
                }
            }
        }
        .sheet(item: $preview) { route in
            NavigationStack {
                if let document = documents.first(where: { $0.id == route.id }) {
                    DocumentPreviewView(document: document, route: route, store: store) {
                        if preview?.id == route.id { preview = nil }
                    }
                }
            }
        }
        .onChange(of: documents.map(\.id)) {
            if let preview, !documents.contains(where: { $0.id == preview.id }) {
                self.preview = nil
            }
        }
        .navigationTitle("Documents")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(importing)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done", systemImage: "checkmark", action: onClose).disabled(importing)
            }
        }
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.pdf, .image]) { result in
            switch result {
            case .success(let url): beginImport(.file(url))
            case .failure(let failure): error = failure.localizedDescription
            }
        }
        .onChange(of: selectedPhoto) { _, photo in
            guard let photo else { return }
            selectedPhoto = nil
            beginImport(.photo(photo))
        }
        .task(id: importRequest?.id) { [importRequest] in
            if let importRequest { await importDocument(importRequest) }
        }
        .onDisappear { importRequest = nil }
        .sheet(item: $pending) { session in
            DocumentEditorView(store: store, session: session)
        }
        .appError($error)
    }

    private func beginImport(_ source: ImportRequest.Source) {
        guard !importing, pending == nil else { return }
        importRequest = ImportRequest(source: source)
    }

    private func importDocument(_ request: ImportRequest) async {
        defer {
            if importRequest?.id == request.id { importRequest = nil }
        }
        do {
            try Task.checkCancellation()
            let asset: DocumentAsset
            let name: String
            switch request.source {
            case .file(let url):
                name = url.deletingPathExtension().lastPathComponent
                asset = try await store.documentStore.importFile(at: url)
            case .photo(let photo):
                guard let data = try await photo.loadTransferable(type: ImportedImage.self) else {
                    throw DocumentError.unsupported
                }
                try Task.checkCancellation()
                name = String(localized: "Document")
                asset = try await store.documentStore.importData(data.data)
            }
            guard !Task.isCancelled, importRequest?.id == request.id else {
                try? await store.documentStore.remove(asset.id)
                return
            }
            do {
                try store.requireManaged(watch)
            } catch {
                try? await store.documentStore.remove(asset.id)
                throw error
            }
            pending = DocumentEditorSession(watch: watch, store: store, asset: asset, proposedName: name)
        } catch {
            if !Task.isCancelled, importRequest?.id == request.id, !(error is CancellationError) {
                self.error = error.localizedDescription
            }
        }
    }
}
