import SwiftData
import XCTest

@testable import MojeZegarki

@MainActor final class PersistenceSafetyTests: XCTestCase {
    private enum Failure: Error { case simulated }
    @MainActor private final class SaveControl {
        var failing = false
        func save(_ context: ModelContext) throws {
            if failing { throw Failure.simulated }
            try context.save()
        }
    }

    private func draft(_ name: String = "Watch") -> TimepieceDraft {
        var draft = TimepieceDraft()
        draft.brand = "Test"
        draft.modelName = name
        return draft
    }

    func testForeignDetachedAndDeletedModelsAreRejectedBeforeMutation() async throws {
        let store = try CollectionStore(inMemory: true)
        let watch = try store.save(draft())
        let foreignContext = ModelContext(store.container)
        let foreign = try XCTUnwrap(foreignContext.fetch(FetchDescriptor<Timepiece>()).first)
        let detached = Timepiece(brand: "Test", modelName: "Detached")
        for model in [foreign, detached] {
            XCTAssertThrowsError(try store.save(draft("Changed"), editing: model))
            XCTAssertThrowsError(try store.changeStatus(.sold, for: model))
            XCTAssertThrowsError(try store.logWear(for: model, date: .now))
            XCTAssertThrowsError(try store.logWear(for: model, dates: [.now]))
            let asset = DocumentAsset(
                id: UUID(), filename: "document.pdf", contentType: "com.adobe.pdf", fileSize: 1, contentHash: "hash")
            XCTAssertThrowsError(
                try store.attachDocument(asset, to: model, name: "Test", kind: .other, date: nil, notes: ""))
            do {
                try await store.delete(model)
                XCTFail("Foreign delete succeeded")
            } catch {}
        }
        XCTAssertEqual(foreign.modelName, "Watch")
        XCTAssertEqual(detached.modelName, "Detached")
        XCTAssertFalse(foreignContext.hasChanges)
        XCTAssertFalse(store.context.hasChanges)
        try await store.delete(watch)
        XCTAssertThrowsError(try store.save(draft("Resurrected"), editing: watch))
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<Timepiece>()), 0)
    }

    func testForeignWishDocumentAndWearMutationsAreRejected() async throws {
        let store = try CollectionStore(inMemory: true)
        let watch = try store.save(draft())
        var wishDraft = WishlistDraft()
        wishDraft.brand = "Test"
        wishDraft.modelName = "Wish"
        _ = try store.saveWish(wishDraft)
        _ = try store.logWear(for: watch, date: .now)
        let asset = DocumentAsset(
            id: UUID(), filename: "document.pdf", contentType: "com.adobe.pdf", fileSize: 1, contentHash: "hash")
        _ = try store.attachDocument(asset, to: watch, name: "Invoice", kind: .purchase, date: nil, notes: "")
        let foreign = ModelContext(store.container)
        let wish = try XCTUnwrap(foreign.fetch(FetchDescriptor<WishlistItem>()).first)
        let log = try XCTUnwrap(foreign.fetch(FetchDescriptor<WearLog>()).first)
        let document = try XCTUnwrap(foreign.fetch(FetchDescriptor<DocumentItem>()).first)
        XCTAssertThrowsError(try store.saveWish(wishDraft, editing: wish))
        XCTAssertThrowsError(try store.moveWish(wish))
        XCTAssertThrowsError(try store.save(draft(), moving: wish))
        XCTAssertThrowsError(try store.logWear(for: watch, date: .now, editing: log))
        XCTAssertThrowsError(try store.deleteWear(log))
        XCTAssertThrowsError(try store.updateDocument(document, name: "Changed", kind: .other, date: nil, notes: ""))
        do {
            try await store.deleteWish(wish)
            XCTFail("Foreign wish delete succeeded")
        } catch {}
        do {
            try await store.deleteDocument(document)
            XCTFail("Foreign document delete succeeded")
        } catch {}
        XCTAssertFalse(foreign.hasChanges)
        XCTAssertFalse(store.context.hasChanges)
    }

    func testRollbackRestoresPhotoGraphAndAllowsRetry() throws {
        let control = SaveControl()
        let store = try CollectionStore(inMemory: true, saveContext: control.save)
        var original = draft()
        let photo = PhotoDraft(id: UUID(), filename: "photo.jpg")
        original.photos = [photo]
        original.mainPhotoID = photo.id
        let watch = try store.save(original)
        var edited = original
        edited.photos = []
        edited.modelName = "Changed"
        control.failing = true
        XCTAssertThrowsError(try store.save(edited, editing: watch))
        XCTAssertEqual(watch.modelName, "Watch")
        XCTAssertEqual(watch.mainPhotoID, photo.id)
        XCTAssertEqual(watch.sortedPhotos.map(\.id), [photo.id])
        XCTAssertFalse(store.context.hasChanges)
        control.failing = false
        try store.save(edited, editing: watch)
        XCTAssertEqual(watch.modelName, "Changed")
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<TimepiecePhoto>()), 0)
    }

    func testFailedMoveAndUndoPreserveOriginalRecordsAndCanBeRetried() throws {
        let control = SaveControl()
        let store = try CollectionStore(inMemory: true, saveContext: control.save)
        var draft = WishlistDraft()
        draft.brand = "Test"
        draft.modelName = "Wish"
        draft.price = "99,95"
        draft.currencyCode = "PLN"
        draft.photo = PhotoDraft(id: UUID(), filename: "photo.jpg")
        let wish = try store.saveWish(draft, locale: Locale(identifier: "pl_PL"))
        let id = wish.id
        control.failing = true
        XCTAssertThrowsError(try store.moveWish(wish))
        XCTAssertEqual(wish.id, id)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<Timepiece>()), 0)
        XCTAssertFalse(store.context.hasChanges)
        control.failing = false
        let undo = try store.moveWish(wish)
        control.failing = true
        XCTAssertThrowsError(try store.undoWishMove(undo))
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<WishlistItem>()), 0)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<TimepiecePhoto>()), 1)
        XCTAssertFalse(store.context.hasChanges)
        control.failing = false
        try store.undoWishMove(undo)
        let restored = try XCTUnwrap(store.context.fetch(FetchDescriptor<WishlistItem>()).first)
        XCTAssertEqual(restored.id, id)
        XCTAssertEqual(restored.targetPrice, "99.95")
        XCTAssertEqual(restored.photoID, draft.photo?.id)
    }

    /// Checks that persisted links and files survive both a failed bulk write and a failed cascade.
    func testFailedBulkAndCascadeDeletionKeepPersistedGraphAndFiles() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let control = SaveControl()
        let store = try CollectionStore(directory: root, saveContext: control.save)
        let watch = try store.save(draft())
        let today = Date.now
        let yesterday = Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: today)!
        control.failing = true
        XCTAssertThrowsError(try store.logWear(for: watch, dates: [today, yesterday]))
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<WearLog>()), 0)
        control.failing = false
        _ = try store.logWear(for: watch, dates: [today, yesterday])
        let asset = DocumentAsset(
            id: UUID(), filename: "document.pdf", contentType: "com.adobe.pdf", fileSize: 1, contentHash: "hash")
        let file = root.appendingPathComponent("Documents/\(asset.id)/document.pdf")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([42]).write(to: file)
        _ = try store.attachDocument(asset, to: watch, name: "Invoice", kind: .purchase, date: nil, notes: "")
        control.failing = true
        do {
            try await store.delete(watch)
            XCTFail("Delete should fail")
        } catch {}
        XCTAssertEqual(watch.wearLogs?.count, 2)
        XCTAssertEqual(watch.documents?.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        XCTAssertFalse(store.context.hasChanges)
        control.failing = false
        try await store.delete(watch)
        let reopened = try CollectionStore(directory: root)
        XCTAssertEqual(try reopened.context.fetchCount(FetchDescriptor<Timepiece>()), 0)
        XCTAssertEqual(try reopened.context.fetchCount(FetchDescriptor<WearLog>()), 0)
        XCTAssertEqual(try reopened.context.fetchCount(FetchDescriptor<DocumentItem>()), 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    /// Exercises changes that can leave stale in-memory values even when a write fails.
    func testFailedScalarAndAttachmentWritesRestoreValuesAndRetry() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let control = SaveControl()
        let store = try CollectionStore(directory: root, saveContext: control.save)
        let watch = try store.save(draft())
        let today = Date.now
        let yesterday = Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: today)!
        let log = try store.logWear(for: watch, date: today)
        let originalDay = log.calendarDay
        let asset = DocumentAsset(
            id: UUID(), filename: "document.pdf", contentType: "com.adobe.pdf", fileSize: 1, contentHash: "hash")
        let document = try store.attachDocument(
            asset, to: watch, name: "Invoice", kind: .purchase, date: nil, notes: "")
        var wishDraft = WishlistDraft()
        wishDraft.brand = "Test"
        wishDraft.modelName = "Wish"
        let wish = try store.saveWish(wishDraft)
        let secondWish = try store.saveWish(wishDraft)
        let positions = [wish.position, secondWish.position]
        wishDraft.modelName = "Changed"
        control.failing = true
        XCTAssertThrowsError(try store.changeStatus(.sold, for: watch))
        XCTAssertEqual(watch.status, .owned)
        XCTAssertThrowsError(try store.logWear(for: watch, date: yesterday, editing: log))
        XCTAssertEqual(log.calendarDay, originalDay)
        XCTAssertThrowsError(try store.logWear(for: watch, date: yesterday))
        XCTAssertEqual(watch.wearLogs?.count, 1)
        XCTAssertThrowsError(
            try store.updateDocument(document, name: "Changed", kind: .other, date: today, notes: "New"))
        XCTAssertEqual(document.displayName, "Invoice")
        XCTAssertEqual(document.kindRaw, "purchase")
        XCTAssertNil(document.documentDate)
        XCTAssertNil(document.notes)
        let otherAsset = DocumentAsset(
            id: UUID(), filename: "other.pdf", contentType: "com.adobe.pdf", fileSize: 1, contentHash: "other")
        XCTAssertThrowsError(
            try store.attachDocument(otherAsset, to: watch, name: "Other", kind: .other, date: nil, notes: ""))
        XCTAssertEqual(watch.documents?.count, 1)
        XCTAssertThrowsError(try store.saveWish(wishDraft, editing: wish))
        XCTAssertEqual(wish.modelName, "Wish")
        XCTAssertThrowsError(try store.reorderWishes([wish.id, secondWish.id], priority: wishDraft.priority))
        XCTAssertEqual([wish.position, secondWish.position], positions)
        XCTAssertFalse(store.context.hasChanges)
        let reopened = try CollectionStore(directory: root)
        XCTAssertEqual(try reopened.context.fetch(FetchDescriptor<Timepiece>()).first?.status, .owned)
        XCTAssertEqual(try reopened.context.fetchCount(FetchDescriptor<WearLog>()), 1)
        XCTAssertEqual(try reopened.context.fetchCount(FetchDescriptor<DocumentItem>()), 1)
        control.failing = false
        try store.logWear(for: watch, date: yesterday, editing: log)
        try store.updateDocument(document, name: "Changed", kind: .other, date: today, notes: "New")
        try store.saveWish(wishDraft, editing: wish)
        try store.changeStatus(.sold, for: watch)
        XCTAssertEqual(watch.status, .sold)
        XCTAssertEqual(document.displayName, "Changed")
        XCTAssertEqual(wish.modelName, "Changed")
        XCTAssertNotEqual(log.calendarDay, originalDay)
    }

    /// Reads the histories from a fresh store before and after retrying the failed reassignment.
    func testFailedWearReassignmentPreservesDiskHistoryUntilRetrySucceeds() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let control = SaveControl()
        let store = try CollectionStore(directory: root, saveContext: control.save)
        let original = try store.save(draft("Original"))
        let replacement = try store.save(draft("Replacement"))
        let now = Date.now
        let log = try store.logWear(for: original, date: now, now: now)
        let id = log.id

        func assertPersistedOwner(_ expectedID: UUID) throws {
            let reopened = try CollectionStore(directory: root)
            let logs = try reopened.context.fetch(FetchDescriptor<WearLog>())
            XCTAssertEqual(logs.map(\.id), [id])
            XCTAssertEqual(logs.first?.timepiece?.id, expectedID)
            let watches = try reopened.context.fetch(FetchDescriptor<Timepiece>())
            XCTAssertEqual(watches.count, 2)
            for watch in watches {
                XCTAssertEqual(watch.wearLogs?.map(\.id) ?? [], watch.id == expectedID ? [id] : [])
            }
        }

        control.failing = true
        XCTAssertThrowsError(try store.logWear(for: replacement, date: now, editing: log, now: now))
        XCTAssertEqual(log.timepiece?.id, original.id)
        XCTAssertEqual(original.wearLogs?.map(\.id), [id])
        XCTAssertTrue((replacement.wearLogs ?? []).isEmpty)
        try assertPersistedOwner(original.id)

        control.failing = false
        try store.logWear(for: replacement, date: now, editing: log, now: now)
        XCTAssertEqual(log.timepiece?.id, replacement.id)
        XCTAssertTrue((original.wearLogs ?? []).isEmpty)
        XCTAssertEqual(replacement.wearLogs?.map(\.id), [id])
        try assertPersistedOwner(replacement.id)
    }

    func testFailedIndividualDeletesRestoreRelationshipsAndRetry() async throws {
        let control = SaveControl()
        let store = try CollectionStore(inMemory: true, saveContext: control.save)
        let watch = try store.save(draft())
        let log = try store.logWear(for: watch, date: .now)
        let asset = DocumentAsset(
            id: UUID(), filename: "document.pdf", contentType: "com.adobe.pdf", fileSize: 1, contentHash: "hash")
        let document = try store.attachDocument(
            asset, to: watch, name: "Invoice", kind: .purchase, date: nil, notes: "")
        var wishDraft = WishlistDraft()
        wishDraft.brand = "Test"
        wishDraft.modelName = "Wish"
        let wish = try store.saveWish(wishDraft)
        control.failing = true
        XCTAssertThrowsError(try store.deleteWear(log))
        do {
            try await store.deleteDocument(document)
            XCTFail("Delete should fail")
        } catch {}
        do {
            try await store.deleteWish(wish)
            XCTFail("Delete should fail")
        } catch {}
        XCTAssertEqual(watch.wearLogs?.map(\.id), [log.id])
        XCTAssertEqual(watch.documents?.map(\.id), [document.id])
        XCTAssertEqual(log.timepiece?.id, watch.id)
        XCTAssertEqual(document.timepiece?.id, watch.id)
        XCTAssertFalse(store.context.hasChanges)
        control.failing = false
        try store.deleteWear(log)
        try await store.deleteDocument(document)
        try await store.deleteWish(wish)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<WearLog>()), 0)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<DocumentItem>()), 0)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<WishlistItem>()), 0)
    }

    /// Keeps independent entries on each watch to detect lost or moved relationships after a failed save.
    func testFailedWearReassignmentKeepsBothWatchHistoriesAndCanBeRetried() throws {
        let control = SaveControl()
        let store = try CollectionStore(inMemory: true, saveContext: control.save)
        let original = try store.save(draft("Original"))
        let replacement = try store.save(draft("Replacement"))
        let now = Date.now
        let log = try store.logWear(for: original, date: now, now: now)
        let id = log.id
        let originalOther = try store.logWear(for: original, on: XCTUnwrap(WearDay(key: "2000-01-01")))
        let replacementOther = try store.logWear(for: replacement, on: XCTUnwrap(WearDay(key: "2000-01-02")))
        func history(_ watch: Timepiece) -> Set<UUID> { Set(watch.wearLogs?.map(\.id) ?? []) }
        XCTAssertEqual(history(original), [id, originalOther.id])
        XCTAssertEqual(history(replacement), [replacementOther.id])

        control.failing = true
        XCTAssertThrowsError(try store.logWear(for: replacement, date: now, editing: log, now: now))
        XCTAssertEqual(log.timepiece?.id, original.id)
        XCTAssertEqual(history(original), [id, originalOther.id])
        XCTAssertEqual(history(replacement), [replacementOther.id])

        control.failing = false
        try store.logWear(for: replacement, date: now, editing: log, now: now)
        XCTAssertEqual(log.timepiece?.id, replacement.id)
        XCTAssertEqual(history(original), [originalOther.id])
        XCTAssertEqual(history(replacement), [id, replacementOther.id])
    }

    func testInMemoryStoresHaveIndependentAssetDirectories() async throws {
        let first = try CollectionStore(inMemory: true)
        let second = try CollectionStore(inMemory: true)
        let firstPhotos = await first.photoStore.root
        let secondPhotos = await second.photoStore.root
        let firstDocuments = await first.documentStore.root
        let secondDocuments = await second.documentStore.root
        XCTAssertNotEqual(firstPhotos, secondPhotos)
        XCTAssertNotEqual(firstDocuments, secondDocuments)
        let file = secondPhotos.appendingPathComponent("\(UUID())/photo.jpg")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([42]).write(to: file)
        try await first.reconcileAssets()
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    /// Keeps the asset actors alive after releasing the collection to verify shared directory ownership.
    func testInMemoryAssetsAreRemovedAfterLastStoreReleasesDirectory() async throws {
        var store: CollectionStore? = try CollectionStore(inMemory: true)
        var photos: PhotoStore? = store?.photoStore
        var documents: DocumentStore? = store?.documentStore
        let photoRoot = await photos?.root
        let root = try XCTUnwrap(photoRoot).deletingLastPathComponent()
        XCTAssertNotNil(documents)
        let marker = root.appendingPathComponent("temporary-asset")
        try Data([42]).write(to: marker)
        store = nil
        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))
        documents = nil
        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))
        photos = nil
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

    func testInMemoryStoreLeavesCallerDirectoryUntouchedOnRelease() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let marker = root.appendingPathComponent("caller-owned")
        try autoreleasepool {
            let store = try CollectionStore(directory: root, inMemory: true)
            try Data([42]).write(to: marker)
            withExtendedLifetime(store) {}
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))
    }
}
