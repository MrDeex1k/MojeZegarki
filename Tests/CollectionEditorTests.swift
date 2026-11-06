import SwiftData
import UIKit
import XCTest

@testable import MojeZegarki

@MainActor final class CollectionEditorTests: XCTestCase {
    func testSuccessfulSessionCannotInsertTwice() async throws {
        let store = try CollectionStore(inMemory: true)
        let session = TimepieceEditorSession(store: store)
        session.draft.brand = "Test"
        session.draft.modelName = "Watch"
        let first = await session.save(in: store, locale: Locale(identifier: "en_US"))
        let second = await session.save(in: store, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(first)
        XCTAssertFalse(second)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<Timepiece>()), 1)
    }

    func testFailedValidationCanBeCorrectedAndRetried() async throws {
        let store = try CollectionStore(inMemory: true)
        let session = TimepieceEditorSession(store: store)
        let failed = await session.save(in: store, locale: Locale(identifier: "en_US"))
        XCTAssertFalse(failed)
        XCTAssertFalse(session.assets.isFinished)
        XCTAssertNotNil(session.error)
        session.draft.brand = "Test"
        session.draft.modelName = "Watch"
        let saved = await session.save(in: store, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(saved)
        XCTAssertNil(session.error)
    }

    func testEditingUsesThePresentedLocaleWithoutChangingExactPrice() async throws {
        let store = try CollectionStore(inMemory: true)
        var draft = TimepieceDraft()
        draft.brand = "Test"
        draft.modelName = "Watch"
        draft.price = "0.000001"
        draft.currencyCode = "PLN"
        let watch = try store.save(draft, locale: Locale(identifier: "en_US"))
        let locale = Locale(identifier: "pl_PL")
        let session = TimepieceEditorSession(store: store, watch: watch, locale: locale)
        XCTAssertEqual(session.draft.price, "0,000001")
        let saved = await session.save(in: store, locale: locale)
        XCTAssertTrue(saved)
        XCTAssertEqual(watch.purchasePrice, "0.000001")
    }

    private func imageData() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).jpegData(withCompressionQuality: 0.8) {
            UIColor.red.setFill()
            $0.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
    }

    /// Checks file lifetime before a failed write and after a successful retry.
    func testFailedDatabaseSaveKeepsBothPhotoSetsUntilRetryCommits() async throws {
        enum Failure: Error { case simulated }
        var failing = false
        let store = try CollectionStore(
            inMemory: true,
            saveContext: {
                if failing { throw Failure.simulated }
                try $0.save()
            })
        var draft = TimepieceDraft()
        draft.brand = "Test"
        draft.modelName = "Watch"
        let original = try await store.photoStore.importPhoto(imageData())
        draft.photos = [original]
        let watch = try store.save(draft)
        let session = TimepieceEditorSession(store: store, watch: watch)
        let replacement = try await store.photoStore.importPhoto(imageData())
        _ = await session.assets.stage(replacement.id)
        session.draft.photos = [replacement]
        session.draft.mainPhotoID = replacement.id
        failing = true
        let failed = await session.save(in: store, locale: Locale(identifier: "en_US"))
        XCTAssertFalse(failed)
        XCTAssertFalse(session.assets.isFinished)
        let oldBytes = await store.photoStore.data(for: original)
        let stagedBytes = await store.photoStore.data(for: replacement)
        XCTAssertNotNil(oldBytes)
        XCTAssertNotNil(stagedBytes)
        XCTAssertEqual(watch.photos?.map(\.id), [original.id])
        failing = false
        let saved = await session.save(in: store, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(saved)
        let removed = await store.photoStore.data(for: original)
        let retained = await store.photoStore.data(for: replacement)
        XCTAssertNil(removed)
        XCTAssertNotNil(retained)
        XCTAssertEqual(watch.photos?.map(\.id), [replacement.id])
    }

    func testDocumentAbandonedBeforePresentationRemovesItsImportedFile() async throws {
        let store = try CollectionStore(inMemory: true)
        var draft = TimepieceDraft()
        draft.brand = "Test"
        draft.modelName = "Watch"
        let watch = try store.save(draft)
        let asset = try await store.documentStore.importData(imageData())
        var session: DocumentEditorSession? = DocumentEditorSession(watch: watch, store: store, asset: asset)
        weak let weakSession = session
        session = nil
        XCTAssertNil(weakSession)
        var bytes: Data?
        for _ in 0..<100 {
            bytes = try? await store.documentStore.data(id: asset.id, filename: asset.filename)
            if bytes == nil { break }
            await Task.yield()
        }
        XCTAssertNil(bytes)
    }

    /// Lets the editor go away while a photo provider is still suspended.
    func testClosingEditorCancelsImportWithoutRetainingTheSession() async throws {
        let store = try CollectionStore(inMemory: true)
        var session: TimepieceEditorSession? = TimepieceEditorSession(store: store)
        let started = expectation(description: "Photo provider started")
        let cancelled = expectation(description: "Provider cancelled")
        session?.importPhotos(
            [
                {
                    started.fulfill()
                    do { try await Task.sleep(for: .seconds(2)) } catch {
                        cancelled.fulfill()
                        throw error
                    }
                    return Data()
                }
            ], from: store.photoStore)
        await fulfillment(of: [started], timeout: 1)
        weak let weakSession = session
        session = nil
        XCTAssertNil(weakSession)
        await fulfillment(of: [cancelled], timeout: 1)
    }
}
