import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct DocumentPreviewView: View {
    let document: DocumentItem
    let store: CollectionStore
    let onClose: () -> Void
    let onDeleteError: (String) -> Void
    @State private var content: PreviewContent?
    @State private var failedToLoad = false
    @State private var editing = false
    @State private var deleting = false
    @State private var confirmingDelete = false

    var body: some View {
        VStack(spacing: 0) {
            if let content {
                switch content {
                case .pdf(let pdf):
                    GeometryReader { geometry in
                        PDFPreview(document: pdf).frame(width: geometry.size.width, height: geometry.size.height)
                    }
                case .image(let image): DocumentImagePreview(image: image)
                }
            } else if failedToLoad {
                ContentUnavailableView(
                    "Document unavailable", systemImage: "doc.badge.ellipsis",
                    description: Text("The document file could not be opened."))
            } else {
                ProgressView("Opening document…").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let notes = document.notes {
                Text(notes).font(.footnote).lineLimit(2).accessibilityIdentifier("document.noteSummary")
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
                NavigationLink {
                    DocumentNotesView(notes: notes)
                } label: {
                    Label("Read full note", systemImage: "text.alignleft")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 44)
                }
                .padding(.horizontal)
                .accessibilityIdentifier("document.readNotes")
            }
        }
        .privacySensitive()
        .navigationTitle(document.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Menu {
                Button("Edit", systemImage: "pencil") { editing = true }
                    .accessibilityIdentifier("document.edit")
                Button("Delete", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                    .accessibilityIdentifier("document.delete")
            } label: {
                Label("Document actions", systemImage: "ellipsis.circle")
            }
            .disabled(deleting).accessibilityIdentifier("document.actions")
        }
        .sheet(isPresented: $editing) {
            if let watch = document.timepiece { DocumentEditorView(watch: watch, store: store, document: document) }
        }
        .confirmationDialog("Delete this document?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                deleting = true
                onClose()
                Task {
                    do { try await store.deleteDocument(document) } catch { onDeleteError(error.localizedDescription) }
                }
            }
            .accessibilityIdentifier("document.confirmDelete")
        }
        .task(id: document.id) {
            content = nil
            failedToLoad = false
            do {
                let data = try await store.documentStore.data(id: document.id, filename: document.filename)
                try Task.checkCancellation()
                if document.contentType == UTType.pdf.identifier {
                    guard let pdf = PDFDocument(data: data), !pdf.isLocked, pdf.pageCount > 0 else {
                        throw DocumentError.unsupported
                    }
                    content = .pdf(pdf)
                } else {
                    guard let image = await ImageLoader.prepare(data) else { throw DocumentError.unsupported }
                    try Task.checkCancellation()
                    content = .image(image)
                }
            } catch is CancellationError {} catch { failedToLoad = true }
        }
    }
}
