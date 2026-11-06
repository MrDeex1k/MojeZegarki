import UIKit
import XCTest

@testable import MojeZegarki

@MainActor
final class StorageProtectionTests: XCTestCase {
    /// Checks that preparation preserves legacy content and that newly imported files can still be opened.
    func testExistingAndNewCollectionFilesRemainReadableAndKeepBackup() async throws {
        try await withProtectedCollection { root, legacy in
            XCTAssertGreaterThan(try collectionFiles(in: root).count, 6)
            XCTAssertEqual(try root.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, false)
            XCTAssertEqual(try String(contentsOf: legacy, encoding: .utf8), "legacy")
        }
    }

    /// Provides a populated fixture while its SwiftData store is still alive.
    private func withProtectedCollection(_ verify: (URL, URL) throws -> Void) async throws {
        // SwiftData can keep the SQLite files open beyond the test's last store reference.
        // Leave this isolated fixture in the system temporary directory for reclamation.
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("StorageProtection-\(UUID())")
        let legacy = root.appendingPathComponent("Documents/legacy/document.pdf")
        try FileManager.default.createDirectory(
            at: legacy.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("legacy".utf8).write(to: legacy, options: .completeFileProtectionUntilFirstUserAuthentication)
        let store = try CollectionStore(directory: root)
        var draft = TimepieceDraft()
        draft.brand = "Private"
        draft.modelName = "Collection"
        _ = try store.save(draft)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).jpegData(withCompressionQuality: 0.8)
        {
            UIColor.white.setFill()
            $0.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        let photo = try await store.photoStore.importPhoto(image)
        let document = try await store.documentStore.importData(image)
        let photoData = await store.photoStore.data(for: photo)
        let documentData = try await store.documentStore.data(id: document.id, filename: document.filename)
        XCTAssertNotNil(photoData)
        XCTAssertFalse(documentData.isEmpty)
        try withExtendedLifetime(store) { try verify(root, legacy) }
    }

    private func collectionFiles(in root: URL) throws -> [URL] {
        let urls = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        return urls.compactMap { $0 as? URL }
    }

    /// Verifies the protection class on both the collection directory and its children.
    private func assertCompleteProtection(in root: URL) throws {
        for url in try [root] + collectionFiles(in: root) {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            XCTAssertEqual(attributes[.protectionKey] as? FileProtectionType, .complete, url.lastPathComponent)
        }
    }

    /// Checks the actual file protection classes on a device, separately from simulated lifecycle events.
    func testCompleteProtectionMetadataOnPhysicalDevice() async throws {
        #if targetEnvironment(simulator)
            throw XCTSkip("Simulator does not expose NSFileProtectionKey. Run on an iPhone with a device passcode.")
        #else
            try await withProtectedCollection { root, _ in
                try assertCompleteProtection(in: root)
            }
        #endif
    }

    func testProtectionLifecycleCanRecoverAfterUnlockNotification() {
        let state = ProtectedDataState()
        NotificationCenter.default.post(name: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil)
        XCTAssertFalse(state.isAvailable)
        NotificationCenter.default.post(name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
        XCTAssertTrue(state.isAvailable)
    }

    func testActivationRefreshesProtectedDataWithoutUnlockNotification() throws {
        try XCTSkipUnless(UIApplication.shared.isProtectedDataAvailable, "Requires an unlocked device")
        let state = ProtectedDataState()
        NotificationCenter.default.post(name: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil)
        XCTAssertFalse(state.isAvailable)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertTrue(state.isAvailable)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertTrue(state.isAvailable)
    }
}
