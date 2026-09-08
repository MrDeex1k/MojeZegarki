import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct DocumentPreviewView: View {
    let document: DocumentItem
    let store: CollectionStore
    let onDeleteError: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var data: Data?
    @State private var failedToLoad = false
    @State private var editing = false
    @State private var deleting = false
    @State private var confirmingDelete = false

    var body: some View {
        VStack(spacing: 0) {
            if let data {
                if document.contentType == UTType.pdf.identifier {
                    PDFPreview(data: data)
                } else if let image = UIImage(data: data) {
                    ZoomableDocumentImage(image: image)
                }
            } else if failedToLoad {
                ContentUnavailableView("Document unavailable", systemImage: "doc.badge.ellipsis", description: Text("The document file could not be opened."))
            } else { ProgressView("Opening document…").frame(maxWidth: .infinity, maxHeight: .infinity) }
            if let notes = document.notes { Text(notes).font(.footnote).padding().frame(maxWidth: .infinity, alignment: .leading) }
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
            } label: { Label("Document actions", systemImage: "ellipsis.circle") }
            .disabled(deleting).accessibilityIdentifier("document.actions")
        }
        .sheet(isPresented: $editing) {
            if let watch = document.timepiece { DocumentEditorView(watch: watch, store: store, document: document) }
        }
        .confirmationDialog("Delete this document?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                deleting = true
                dismiss()
                Task {
                    do { try await store.deleteDocument(document) }
                    catch { onDeleteError(error.localizedDescription) }
                }
            }
            .accessibilityIdentifier("document.confirmDelete")
        }
        .task(id: document.id) {
            do { data = try await store.documentStore.data(id: document.id, filename: document.filename) }
            catch { failedToLoad = true }
        }
    }
}

private struct PDFPreview: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.document = PDFDocument(data: data)
        view.accessibilityLabel = String(localized: "Document preview")
        return view
    }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}

private struct ZoomableDocumentImage: UIViewRepresentable {
    let image: UIImage
    func makeUIView(context: Context) -> ImageScrollView { ImageScrollView(image: image) }
    func updateUIView(_ uiView: ImageScrollView, context: Context) {}

    final class ImageScrollView: UIScrollView, UIScrollViewDelegate {
        let imageView: UIImageView
        init(image: UIImage) {
            imageView = UIImageView(image: image)
            super.init(frame: .zero)
            imageView.contentMode = .scaleAspectFit
            imageView.isAccessibilityElement = true
            imageView.accessibilityLabel = String(localized: "Document preview")
            addSubview(imageView)
            minimumZoomScale = 1
            maximumZoomScale = 5
            delegate = self
        }
        required init?(coder: NSCoder) { nil }
        override func layoutSubviews() {
            super.layoutSubviews()
            if zoomScale == 1 { imageView.frame = bounds; contentSize = bounds.size }
        }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    }
}
