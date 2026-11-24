import PDFKit
import UIKit

enum PreviewContent {
    case pdf(PDFDocument)
    case image(UIImage)

    @concurrent static func preparePDF(_ data: Data) async throws -> sending PDFDocument {
        try Task.checkCancellation()
        guard let document = PDFDocument(data: data), !document.isLocked, document.pageCount > 0 else {
            throw DocumentError.unsupported
        }
        return document
    }
}
