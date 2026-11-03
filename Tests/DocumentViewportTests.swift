import UIKit
import XCTest

@testable import MojeZegarki

@MainActor
final class DocumentViewportTests: XCTestCase {
    func testZoomedDocumentAdaptsToResizedViewportWithoutResettingZoom() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 1200)).image { _ in }
        let view = ZoomableDocumentImage.ImageScrollView(image: image)
        let delegate = ZoomableDocumentImage.Coordinator(zoom: .constant(3))
        view.delegate = delegate
        view.frame = CGRect(x: 0, y: 0, width: 300, height: 500)
        view.layoutIfNeeded()
        view.setZoomScale(3, animated: false)
        view.contentOffset = CGPoint(x: 200, y: 400)

        view.frame.size = CGSize(width: 700, height: 400)
        view.setNeedsLayout()
        view.layoutIfNeeded()

        XCTAssertEqual(view.zoomScale, 3, accuracy: 0.01)
        XCTAssertEqual(view.contentSize.width, 2100, accuracy: 1)
        XCTAssertEqual(view.contentSize.height, 1200, accuracy: 1)
        XCTAssertGreaterThanOrEqual(view.contentOffset.x, 0)
        XCTAssertLessThanOrEqual(view.contentOffset.x, view.contentSize.width - view.bounds.width)
        XCTAssertGreaterThanOrEqual(view.contentOffset.y, 0)
        XCTAssertLessThanOrEqual(view.contentOffset.y, view.contentSize.height - view.bounds.height)
    }
}
