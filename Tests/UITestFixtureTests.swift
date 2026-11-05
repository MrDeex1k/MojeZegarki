import SwiftData
import XCTest

@testable import MojeZegarki

@MainActor final class UITestFixtureTests: XCTestCase {
    func testRepeatedAndPartiallyCompletedSeedingKeepsIndependentPhotoOwners() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = try CollectionStore(directory: root)
        let configuration = AppLaunchConfiguration(arguments: [
            "--uitesting", "--test-photo-preview-fixture", "--test-document-fixture", "--test-wear-fixture",
        ])
        let fixtures = UITestFixtures(configuration: configuration, directory: root)
        try await fixtures.seed(in: store)
        // A completed run is skipped, even after a fixture was edited by a test.
        let wish = try XCTUnwrap(store.context.fetch(FetchDescriptor<WishlistItem>()).first)
        let photoWatch = try XCTUnwrap(
            store.context.fetch(FetchDescriptor<Timepiece>()).first { $0.modelName == "Photo watch" })
        let photo = try XCTUnwrap(wish.photo)
        XCTAssertFalse(photoWatch.sortedPhotos.contains { $0.id == photo.id })
        try await fixtures.seed(in: store)
        // Simulate interruption before completion markers were written.
        for name in ["photos", "documents", "wear"] {
            try FileManager.default.removeItem(at: root.appendingPathComponent("fixture-\(name)-v1.ready"))
        }
        try await fixtures.seed(in: store)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<Timepiece>()), 4)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<WishlistItem>()), 1)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<DocumentItem>()), 1)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<WearLog>()), 1)
        try await store.delete(photoWatch)
        let bytes = await store.photoStore.data(for: photo)
        XCTAssertNotNil(bytes)
        try await fixtures.seed(in: store)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<Timepiece>()), 3)
    }
}
