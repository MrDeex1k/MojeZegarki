import UIKit
import XCTest

@testable import MojeZegarki

@MainActor final class ImageLoadingTests: XCTestCase {
    func testUnlockAndActivationRefreshBothRetryInterruptedImageLoads() {
        let state = ProtectedDataState()
        NotificationCenter.default.post(name: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil)
        XCTAssertFalse(state.isAvailable)
        let beforeUnlock = ImageLoader.access.revision
        NotificationCenter.default.post(name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
        XCTAssertTrue(state.isAvailable)
        XCTAssertNotEqual(ImageLoader.access.revision, beforeUnlock)
        NotificationCenter.default.post(name: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil)
        let beforeActivation = ImageLoader.access.revision
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertTrue(state.isAvailable)
        XCTAssertNotEqual(ImageLoader.access.revision, beforeActivation)
    }

    private func fixture() async throws -> (PhotoStore, PhotoDraft) {
        ImageLoader.clearCache()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = PhotoStore(root: root)
        let data = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).jpegData(withCompressionQuality: 0.8) {
            UIColor.red.setFill()
            $0.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
        return (store, try await store.importPhoto(data))
    }

    func testClearRejectsAnImageAlreadyBeingDecoded() async throws {
        let (store, photo) = try await fixture()
        let started = expectation(description: "Decoding started")
        var resume: CheckedContinuation<Void, Never>?
        let task = Task {
            await ImageLoader.load(photo, store: store, thumbnail: true) { bytes in
                await withCheckedContinuation {
                    resume = $0
                    started.fulfill()
                }
                return UIImage(data: bytes)
            }
        }
        await fulfillment(of: [started], timeout: 2)
        ImageLoader.clearCache()
        resume?.resume()
        let result = await task.value
        XCTAssertNil(result)
        let root = await store.root
        try FileManager.default.removeItem(at: root.appendingPathComponent(photo.id.uuidString))
        let cached = await ImageLoader.load(photo, store: store, thumbnail: true)
        XCTAssertNil(cached)
    }

    func testRemovingPhotoInvalidatesItsCachedThumbnail() async throws {
        for reconcile in [false, true] {
            let (store, photo) = try await fixture()
            let first = await ImageLoader.load(photo, store: store, thumbnail: true)
            XCTAssertNotNil(first)
            if reconcile { try await store.removeUnreferenced(keeping: []) } else { try await store.remove(photo.id) }
            let removed = await ImageLoader.load(photo, store: store, thumbnail: true)
            XCTAssertNil(removed)
        }
    }

    func testRemovalRejectsLateDecodeWithoutInvalidatingOtherPhotos() async throws {
        let (store, photo) = try await fixture()
        let bytes = await store.data(for: photo, thumbnail: false)
        let other = try await store.importPhoto(XCTUnwrap(bytes))
        let cached = await ImageLoader.load(other, store: store, thumbnail: true)
        let started = expectation(description: "Decoding started")
        var resume: CheckedContinuation<Void, Never>?
        let task = Task {
            await ImageLoader.load(photo, store: store, thumbnail: true) { bytes in
                await withCheckedContinuation {
                    resume = $0
                    started.fulfill()
                }
                return UIImage(data: bytes)
            }
        }
        await fulfillment(of: [started], timeout: 2)
        try await store.remove(photo.id)
        resume?.resume()
        let result = await task.value
        XCTAssertNil(result)
        let unaffected = await ImageLoader.load(other, store: store, thumbnail: true)
        XCTAssertTrue(cached === unaffected)
    }

    func testCancelledLoadDoesNotReturnCachedImage() async throws {
        let (store, photo) = try await fixture()
        _ = await ImageLoader.load(photo, store: store, thumbnail: true)
        let task = Task { await ImageLoader.load(photo, store: store, thumbnail: true) }
        task.cancel()
        let result = await task.value
        XCTAssertNil(result)
    }
}
