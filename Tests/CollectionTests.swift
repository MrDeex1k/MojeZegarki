import XCTest
import SwiftData
import UIKit
import ImageIO
@testable import MojeZegarki

@MainActor
final class CollectionTests: XCTestCase {
    private var directory: URL!

    override func setUp() async throws {
        await MainActor.run {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        }
    }

    override func tearDown() async throws {
        try await MainActor.run {
            let photos = directory.appendingPathComponent("Photos")
            if FileManager.default.fileExists(atPath: photos.path) {
                try FileManager.default.removeItem(at: photos)
            }
            // SwiftData may retain SQLite handles beyond the test's lifetime.
            // Leave isolated temporary databases until the runner process exits.
        }
    }

    private func draft() -> TimepieceDraft {
        var value = TimepieceDraft()
        value.brand = "  Seiko  "
        value.modelName = "Prospex"
        return value
    }

    func testRequiredFieldsAndExactLocalizedMoney() throws {
        var value = draft()
        XCTAssertNil(try value.validatedPrice())
        value.price = "1234,56"
        value.currencyCode = "PLN"
        XCTAssertEqual(try value.validatedPrice(locale: Locale(identifier: "pl_PL")), "1234.56")
        value.price = "0"
        XCTAssertEqual(try value.validatedPrice(), "0")
        for invalid in ["-1", "12junk", "1,234.56", "1.2.3", "NaN", "99999999999999999999999"] {
            value.price = invalid
            XCTAssertThrowsError(try value.validatedPrice(locale: Locale(identifier: "en_US")))
        }
        value.price = "12.50"
        value.currencyCode = ""
        XCTAssertThrowsError(try value.validatedPrice(locale: Locale(identifier: "en_US")))
        value.currencyCode = "USD"
        value.brand = " \n "
        XCTAssertThrowsError(try value.validatedPrice())
    }

    func testDiskPersistenceAndEditingWithoutAutosave() throws {
        var savedID: UUID!
        do {
            let store = try CollectionStore(directory: directory)
            var value = draft()
            value.price = "1234,56"
            value.currencyCode = "PLN"
            value.categories = [.diver, .sport]
            let watch = try store.save(value, locale: Locale(identifier: "pl_PL"))
            savedID = watch.id
            XCTAssertEqual(watch.brand, "Seiko")
            var abandonedEdit = TimepieceDraft(timepiece: watch)
            abandonedEdit.brand = "Not saved"
            XCTAssertEqual(watch.brand, "Seiko")
            XCTAssertFalse(store.context.autosaveEnabled)
        }
        let reopened = try CollectionStore(directory: directory)
        let watch = try XCTUnwrap(reopened.context.fetch(FetchDescriptor<Timepiece>()).first)
        XCTAssertEqual(watch.id, savedID)
        XCTAssertEqual(watch.brand, "Seiko")
        XCTAssertEqual(watch.purchasePrice, "1234.56")
        XCTAssertEqual(Set(watch.categoryIDs), ["diver", "sport"])
        var edit = TimepieceDraft(timepiece: watch)
        edit.modelName = "Alpinist"
        try reopened.save(edit, editing: watch)
        XCTAssertEqual(try reopened.context.fetchCount(FetchDescriptor<Timepiece>()), 1)
        XCTAssertEqual(watch.modelName, "Alpinist")
    }

    func testArchiveRestoreAndCascadeDeletionWithPhotos() async throws {
        let store = try CollectionStore(directory: directory)
        let photo = try await store.photoStore.importPhoto(testImage())
        var value = draft()
        value.photos = [photo]
        value.mainPhotoID = photo.id
        let watch = try store.save(value)
        try store.changeStatus(.sold, for: watch)
        XCTAssertEqual(watch.status, .sold)
        XCTAssertEqual(watch.sortedPhotos.count, 1)
        try store.changeStatus(.destroyed, for: watch)
        XCTAssertEqual(watch.status, .destroyed)
        try store.changeStatus(.owned, for: watch)
        XCTAssertEqual(watch.mainPhoto?.id, photo.id)
        try await store.delete(watch)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<Timepiece>()), 0)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<TimepiecePhoto>()), 0)
        let bytes = await store.photoStore.data(for: photo)
        XCTAssertNil(bytes)
    }

    func testPhotoEncodingThumbnailAndRecoveryOfUnreferencedFiles() async throws {
        let store = try CollectionStore(directory: directory)
        let kept = try await store.photoStore.importPhoto(testImage())
        let orphan = try await store.photoStore.importPhoto(testImage())
        let thumbnail = await store.photoStore.data(for: kept)
        let full = await store.photoStore.data(for: kept, thumbnail: false)
        let thumbnailImage = try XCTUnwrap(UIImage(data: XCTUnwrap(thumbnail)))
        let fullImage = try XCTUnwrap(UIImage(data: XCTUnwrap(full)))
        XCTAssertLessThanOrEqual(max(thumbnailImage.size.width, thumbnailImage.size.height), 600)
        XCTAssertLessThanOrEqual(max(fullImage.size.width, fullImage.size.height), 2400)
        XCTAssertTrue(["photo.heic", "photo.jpg"].contains(kept.filename))
        var value = draft()
        value.photos = [kept]
        let watch = try store.save(value)
        XCTAssertEqual(watch.mainPhoto?.id, kept.id)
        try await store.reconcilePhotos()
        let orphanBytes = await store.photoStore.data(for: orphan)
        let keptBytes = await store.photoStore.data(for: kept)
        XCTAssertNil(orphanBytes)
        XCTAssertNotNil(keptBytes)
        do {
            _ = try await store.photoStore.importPhoto(Data("not an image".utf8))
            XCTFail("Invalid image must not be imported")
        } catch { XCTAssertTrue(error is CollectionError) }
    }

    func testRemovingMainPhotoChoosesRemainingPhoto() async throws {
        let store = try CollectionStore(directory: directory)
        let first = try await store.photoStore.importPhoto(testImage())
        let second = try await store.photoStore.importPhoto(testImage())
        var value = draft()
        value.photos = [first, second]
        value.mainPhotoID = first.id
        let watch = try store.save(value)
        value.photos = [second]
        try store.save(value, editing: watch)
        XCTAssertEqual(watch.mainPhotoID, second.id)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<TimepiecePhoto>()), 1)
        try await store.reconcilePhotos()
        let removedBytes = await store.photoStore.data(for: first)
        XCTAssertNil(removedBytes)
    }

    private func testImage() -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 2800, height: 1600), format: format).jpegData(withCompressionQuality: 0.9) { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2800, height: 1600))
            UIColor.white.setFill()
            context.fill(CGRect(x: 600, y: 300, width: 800, height: 800))
        }
    }
}
