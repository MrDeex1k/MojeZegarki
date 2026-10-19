import PDFKit
import UIKit
import XCTest

@testable import MojeZegarki

@MainActor
final class DocumentComplexityTests: XCTestCase {
    func testMultipagePDFImportAndPreviewPreparation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DocumentStore(root: root)
        for count in [1, 100, 1000] {
            let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 600, height: 800)).pdfData { context in
                for page in 0..<count {
                    context.beginPage()
                    ("Invoice \(page)" as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: nil)
                }
            }
            let clock = ContinuousClock()
            let start = clock.now
            let asset = try await store.importData(data)
            let importTime = start.duration(to: clock.now)
            let bytes = try await store.data(id: asset.id, filename: asset.filename)
            let previewStart = clock.now
            let preview = try XCTUnwrap(PDFDocument(data: bytes))
            XCTAssertEqual(preview.pageCount, count)
            _ = preview.page(at: 0)?.thumbnail(of: CGSize(width: 300, height: 400), for: .mediaBox)
            print(
                "PDF_COMPLEXITY pages=\(count) bytes=\(data.count) import=\(importTime) previewAndFirstPage=\(previewStart.duration(to: clock.now))"
            )
            XCTAssertEqual(bytes, data)
        }
    }

    func testPDFByteBoundaryAndCancelledImportDoNotLeaveFiles() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DocumentStore(root: root)
        var data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 100, height: 100)).pdfData { $0.beginPage() }
        data.append(Data(repeating: 32, count: DocumentStore.maximumBytes - data.count))
        let asset = try await store.importData(data)
        XCTAssertEqual(asset.fileSize, DocumentStore.maximumBytes)
        data.append(32)
        do {
            _ = try await store.importData(data)
            XCTFail("Expected size rejection")
        } catch DocumentError.tooLarge {}
        let task = Task { try await store.importData(Data("%PDF-cancelled".utf8)) }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {}
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path).count, 1)
    }
}
