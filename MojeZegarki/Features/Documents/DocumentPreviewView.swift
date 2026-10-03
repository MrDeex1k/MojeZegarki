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
                case .image(let image): ZoomableDocumentImage(image: image)
                }
            } else if failedToLoad {
                ContentUnavailableView(
                    "Document unavailable", systemImage: "doc.badge.ellipsis",
                    description: Text("The document file could not be opened."))
            } else {
                ProgressView("Opening document…").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let notes = document.notes {
                Text(notes).font(.footnote).padding().frame(maxWidth: .infinity, alignment: .leading)
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

private enum PreviewContent {
    case pdf(PDFDocument)
    case image(UIImage)
}

private struct PDFPreview: UIViewRepresentable {
    let document: PDFDocument
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.document = document
        view.accessibilityLabel = String(localized: "Document preview")
        return view
    }
    func updateUIView(_ uiView: PDFView, context: Context) {}
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PDFView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }
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
            if zoomScale == 1 {
                imageView.frame = bounds
                contentSize = bounds.size
            }
        }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    }
}
