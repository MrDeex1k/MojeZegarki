import PDFKit
import SwiftUI

struct PDFPreview: UIViewRepresentable {
    let document: PDFDocument
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.accessibilityIdentifier = "document.pdfPreview"
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
