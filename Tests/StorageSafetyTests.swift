import SwiftData
import XCTest

@testable import MojeZegarki

@MainActor
final class StorageSafetyTests: XCTestCase {
    private enum Failure: Error { case simulated }

    func testPhotoCleanupFailureStillAttemptsDocumentCleanup() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = try CollectionStore(directory: root)
        let orphan = root.appendingPathComponent("Documents").appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: orphan, withIntermediateDirectories: true)
        do {
            try await store.reconcileAssets(cleanPhotos: { _ in throw Failure.simulated })
            XCTFail("Expected cleanup failure")
        } catch let error as AssetReconciliationError {
            XCTAssertEqual(error.failures.count, 1)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path))
    }

    func testBothCleanupFailuresAreReported() async throws {
        let store = try CollectionStore(inMemory: true)
        var documentsAttempted = false
        do {
            try await store.reconcileAssets(
                cleanPhotos: { _ in throw Failure.simulated },
                cleanDocuments: { _ in
                    documentsAttempted = true
                    throw Failure.simulated
                })
            XCTFail("Expected cleanup failures")
        } catch let error as AssetReconciliationError {
            XCTAssertEqual(error.failures.count, 2)
        }
        XCTAssertTrue(documentsAttempted)
    }

    func testWishlistReadFailureDoesNotInsertOrMutateModels() throws {
        let store = try CollectionStore(inMemory: true)
        var draft = WishlistDraft()
        draft.brand = "Seiko"
        draft.modelName = "Original"
        let existing = try store.saveWish(draft)
        draft.modelName = "Changed"
        draft.priority = .high
        XCTAssertThrowsError(try store.saveWish(draft, editing: existing, fetchPeers: { _ in throw Failure.simulated }))
        XCTAssertEqual(existing.modelName, "Original")
        XCTAssertEqual(existing.priority, 0)
        XCTAssertFalse(store.context.hasChanges)
        XCTAssertThrowsError(try store.saveWish(draft, fetchPeers: { _ in throw Failure.simulated }))
        XCTAssertFalse(store.context.hasChanges)
        try store.context.save()
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<WishlistItem>()), 1)
    }
}
