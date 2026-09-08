import XCTest
import SwiftData
import UIKit
@testable import MojeZegarki

@MainActor
final class FreeModuleTests: XCTestCase {
    private func store() throws -> CollectionStore {
        try CollectionStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }

    private func watch(_ store: CollectionStore, model: String = "Explorer") throws -> Timepiece {
        var draft = TimepieceDraft()
        draft.brand = "Rolex"
        draft.modelName = model
        return try store.save(draft)
    }

    private func pdf() -> Data {
        UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 600)).pdfData { context in
            context.beginPage()
            ("Invoice 123 / Test document" as NSString).draw(at: CGPoint(x: 30, y: 30), withAttributes: nil)
        }
    }

    func testV1MigrationPreservesWatchPhotoAndPurchase() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let photoID = UUID()
        try autoreleasepool {
            let schema = Schema(versionedSchema: CollectionSchemaV1.self)
            let config = ModelConfiguration(schema: schema, url: root.appendingPathComponent("collection.store"), cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let old = CollectionSchemaV1.Timepiece(brand: "Seiko", modelName: "Legacy")
            container.mainContext.insert(old)
            old.purchasePrice = "1234.56"
            old.currencyCode = "PLN"
            old.statusRaw = "sold"
            let photo = CollectionSchemaV1.TimepiecePhoto(id: photoID, filename: "photo.jpg", position: 0)
            old.photos = [photo]
            old.mainPhotoID = photoID
            photo.timepiece = old
            try container.mainContext.save()
        }
        let migrated = try CollectionStore(directory: root)
        let value = try XCTUnwrap(migrated.context.fetch(FetchDescriptor<Timepiece>()).first)
        XCTAssertEqual(value.modelName, "Legacy")
        XCTAssertEqual(value.status, .sold)
        XCTAssertEqual(value.purchasePrice, "1234.56")
        XCTAssertEqual(value.mainPhoto?.id, photoID)
        XCTAssertEqual(value.mainPhoto?.timepiece?.id, value.id)
        XCTAssertTrue((value.wearLogs ?? []).isEmpty)
        XCTAssertEqual(try migrated.context.fetchCount(FetchDescriptor<WishlistItem>()), 0)
    }

    func testWearDayTimeZonesAndInvalidCalendarDates() throws {
        let utc = TimeZone(secondsFromGMT: 0)!
        let warsaw = TimeZone(identifier: "Europe/Warsaw")!
        let newYork = TimeZone(identifier: "America/New_York")!
        let instant = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-28T23:30:00Z"))
        XCTAssertEqual(WearDay(instant, timeZone: warsaw).key, "2026-03-29")
        XCTAssertEqual(WearDay(instant, timeZone: newYork).key, "2026-03-28")
        let day = try XCTUnwrap(WearDay(key: "2026-03-29"))
        for zone in [utc, warsaw, newYork] {
            XCTAssertEqual(WearDay(try XCTUnwrap(day.date(timeZone: zone)), timeZone: zone), day)
        }
        for invalid in ["2026-02-29", "2026-13-01", "2026-00-12", "2026-1-01", "invalid"] {
            XCTAssertNil(WearDay(key: invalid))
        }
        XCTAssertNotNil(WearDay(key: "2024-02-29"))
    }

    func testWearIdempotenceEditingArchiveAndCascade() async throws {
        let store = try store()
        let first = try watch(store)
        let second = try watch(store, model: "Submariner")
        let zone = TimeZone(secondsFromGMT: 0)!
        let today = WearDay(key: "2026-09-07")!.date(timeZone: zone)!
        let yesterday = today.addingTimeInterval(-86400)
        let log = try store.logWear(for: first, date: today, now: today, timeZone: zone)
        let duplicate = try store.logWear(for: first, date: today, now: today, timeZone: zone)
        XCTAssertEqual(log.id, duplicate.id)
        try store.logWear(for: second, date: today, now: today, timeZone: zone)
        let past = try store.logWear(for: first, date: yesterday, now: today, timeZone: zone)
        XCTAssertThrowsError(try store.logWear(for: first, date: today, editing: past, now: today, timeZone: zone))
        XCTAssertEqual(past.calendarDay, "2026-09-06")
        XCTAssertThrowsError(try store.logWear(for: first, date: today.addingTimeInterval(86400), now: today, timeZone: zone))
        try store.changeStatus(.sold, for: first)
        XCTAssertThrowsError(try store.logWear(for: first, date: today, now: today, timeZone: zone))
        try store.logWear(for: first, date: yesterday.addingTimeInterval(-86400), now: today, timeZone: zone)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<WearLog>()), 4)
        try store.deleteWear(past)
        try await store.delete(first)
        let remaining = try store.context.fetch(FetchDescriptor<WearLog>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.timepiece?.id, second.id)
    }

    func testWishlistValidationAndAtomicConversionPreservesPhoto() async throws {
        let store = try store()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).jpegData(withCompressionQuality: 0.9) { context in
            UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        let photo = try await store.photoStore.importPhoto(image)
        var draft = WishlistDraft()
        draft.brand = "  Casio "
        draft.modelName = "G-Shock"
        draft.url = "https://example.com/watch"
        draft.price = "199,99"
        draft.currencyCode = "PLN"
        draft.photo = photo
        draft.priority = .high
        let wish = try store.saveWish(draft, locale: Locale(identifier: "pl_PL"))
        XCTAssertEqual(wish.brand, "Casio")
        XCTAssertEqual(wish.targetPrice, "199.99")
        try await store.reconcilePhotos()
        let retained = await store.photoStore.data(for: photo)
        XCTAssertNotNil(retained)
        for invalid in ["file:///etc/passwd", "javascript:alert(1)", "https://user:secret@example.com", "example.com"] {
            draft.url = invalid
            XCTAssertThrowsError(try store.saveWish(draft, editing: wish, locale: Locale(identifier: "pl_PL")))
        }
        XCTAssertEqual(wish.url, "https://example.com/watch")
        var conversion = WishlistDraft(item: wish, locale: Locale(identifier: "en_US")).purchaseDraft
        conversion.brand = ""
        XCTAssertThrowsError(try store.save(conversion, moving: wish))
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<WishlistItem>()), 1)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<Timepiece>()), 0)
        conversion.brand = "Casio"
        let purchased = try store.save(conversion, moving: wish, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<WishlistItem>()), 0)
        XCTAssertEqual(purchased.mainPhoto?.id, photo.id)
        XCTAssertEqual(purchased.purchasePrice, "199.99")
        try await store.reconcilePhotos()
        let moved = await store.photoStore.data(for: photo)
        XCTAssertNotNil(moved)
    }

    func testDocumentsPrivateCopyDuplicatesLimitsAndCascade() async throws {
        let store = try store()
        let owner = try watch(store)
        let another = try watch(store, model: "Other")
        let data = pdf()
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        try data.write(to: source)
        let asset = try await store.documentStore.importFile(at: source)
        try FileManager.default.removeItem(at: source)
        let copy = try await store.documentStore.data(id: asset.id, filename: asset.filename)
        XCTAssertEqual(copy, data)
        let document = try store.attachDocument(asset, to: owner, name: "Invoice", kind: .purchase, date: nil, notes: "Private")
        try store.updateDocument(document, name: "Warranty", kind: .warranty, date: .now, notes: "Updated")
        XCTAssertEqual(document.kindRaw, "warranty")
        let duplicate = try await store.documentStore.importData(data)
        XCTAssertThrowsError(try store.attachDocument(duplicate, to: owner, name: "Copy", kind: .purchase, date: nil, notes: ""))
        let other = try store.attachDocument(duplicate, to: another, name: "Shared source", kind: .other, date: nil, notes: "")
        let orphan = try await store.documentStore.importData(data)
        try await store.reconcilePhotos()
        do { _ = try await store.documentStore.data(id: orphan.id, filename: orphan.filename); XCTFail("Orphan must be removed") }
        catch { XCTAssertTrue(error is DocumentError) }
        for invalid in [Data("broken".utf8), Data(repeating: 0, count: DocumentStore.maximumBytes + 1)] {
            do { _ = try await store.documentStore.importData(invalid); XCTFail("Invalid file accepted") }
            catch { XCTAssertTrue(error is DocumentError) }
        }
        try await store.delete(owner)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<DocumentItem>()), 1)
        do { _ = try await store.documentStore.data(id: asset.id, filename: asset.filename); XCTFail("Deleted document file retained") }
        catch { XCTAssertTrue(error is DocumentError) }
        try await store.deleteDocument(other)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<DocumentItem>()), 0)
    }

    func testDocumentImageConversionPreservesReadableResolution() async throws {
        let store = try store()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let source = UIGraphicsImageRenderer(size: CGSize(width: 4200, height: 2400), format: format).jpegData(withCompressionQuality: 1) { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4200, height: 2400))
            ("TEST INVOICE 1234.56 PLN" as NSString).draw(at: CGPoint(x: 100, y: 100), withAttributes: [.font: UIFont.systemFont(ofSize: 80)])
        }
        let asset = try await store.documentStore.importData(source)
        XCTAssertTrue(["document.heic", "document.jpg"].contains(asset.filename))
        let bytes = try await store.documentStore.data(id: asset.id, filename: asset.filename)
        let image = try XCTUnwrap(UIImage(data: bytes))
        XCTAssertEqual(max(image.size.width, image.size.height), 4000)
        XCTAssertLessThanOrEqual(bytes.count, DocumentStore.maximumBytes)
    }
}
