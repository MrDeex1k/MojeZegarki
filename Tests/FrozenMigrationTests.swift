import SwiftData
import XCTest

@testable import MojeZegarki

@MainActor final class FrozenMigrationTests: XCTestCase {
    func testFrozenV1PreservesIdentityMoneyAndPhotoAfterMigrationAndCleanup() async throws {
        let root = try copyFixture(version: 1)
        let photoID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let file = try seedFile(root, path: "Photos/\(photoID)/photo.jpg")
        let store = try await CollectionStore.open(directory: root)
        let watch = try XCTUnwrap(store.context.fetch(FetchDescriptor<Timepiece>()).first)
        XCTAssertEqual(watch.id.uuidString, "11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(watch.purchasePrice, "1234.560001")
        XCTAssertEqual(watch.currencyCode, "PLN")
        XCTAssertEqual(watch.status, .sold)
        XCTAssertEqual(watch.serialNumber, "fixture-serial")
        XCTAssertEqual(Set(watch.categoryIDs), ["diver", "sport"])
        XCTAssertEqual(watch.mainPhoto?.id, photoID)
        XCTAssertEqual(watch.mainPhoto?.timepiece?.id, watch.id)
        try await store.reconcileAssets()
        XCTAssertEqual(try Data(contentsOf: file), Data("legacy bytes".utf8))
        let reopened = try CollectionStore(directory: root)
        XCTAssertEqual(try reopened.context.fetchCount(FetchDescriptor<Timepiece>()), 1)
    }

    func testFrozenV2PreservesEveryRelationshipAndWishlistOrder() async throws {
        let root = try copyFixture(version: 2)
        let files = try [
            "Photos/44444444-4444-4444-4444-444444444444/photo.jpg",
            "Documents/55555555-5555-5555-5555-555555555555/document.pdf",
            "Photos/66666666-6666-6666-6666-666666666666/photo.jpg",
        ].map { try seedFile(root, path: $0) }
        let store = try await CollectionStore.open(directory: root)
        let watch = try XCTUnwrap(store.context.fetch(FetchDescriptor<Timepiece>()).first)
        XCTAssertEqual(watch.id.uuidString, "33333333-3333-3333-3333-333333333333")
        XCTAssertEqual(watch.photos?.count, 1)
        XCTAssertEqual(watch.wearLogs?.first?.calendarDay, "2026-10-01")
        let document = try XCTUnwrap(watch.documents?.first)
        XCTAssertEqual(document.id.uuidString, "55555555-5555-5555-5555-555555555555")
        XCTAssertEqual(document.timepiece?.id, watch.id)
        XCTAssertEqual(document.contentHash, "fixture-hash")
        XCTAssertEqual(document.fileSize, 123)
        XCTAssertEqual(document.notes, "Fixture note")
        XCTAssertEqual(document.kindRaw, "service")
        let wishes = try store.context.fetch(
            FetchDescriptor<WishlistItem>(sortBy: [
                SortDescriptor(\.priority, order: .reverse), SortDescriptor(\.position),
                SortDescriptor(\.createdAt, order: .reverse),
            ]))
        XCTAssertEqual(wishes.map(\.modelName), ["Wish 2", "Wish 1", "Wish 0"])
        XCTAssertTrue(
            wishes.allSatisfy { $0.position == 0 && $0.targetPrice == "0.000001" && $0.currencyCode == "PLN" })
        XCTAssertNotNil(wishes[1].photo)
        XCTAssertEqual(wishes[1].url, "https://example.com/watch")
        try await store.reconcileAssets()
        for file in files { XCTAssertEqual(try Data(contentsOf: file), Data("legacy bytes".utf8)) }
        let reopened = try CollectionStore(directory: root)
        XCTAssertEqual(try reopened.context.fetchCount(FetchDescriptor<DocumentItem>()), 1)
        XCTAssertEqual(try reopened.context.fetchCount(FetchDescriptor<WishlistItem>()), 3)
    }

    private func copyFixture(version: Int) throws -> URL {
        let source = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "collection-v\(version)", withExtension: "store"))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: source, to: root.appendingPathComponent("collection.store"))
        return root
    }

    private func seedFile(_ root: URL, path: String) throws -> URL {
        let file = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("legacy bytes".utf8).write(to: file)
        return file
    }
}
