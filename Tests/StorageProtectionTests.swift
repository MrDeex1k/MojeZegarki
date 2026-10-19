import UIKit
import XCTest

@testable import MojeZegarki

@MainActor
final class StorageProtectionTests: XCTestCase {
    func testExistingAndNewCollectionFilesRemainReadableAndKeepBackup() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
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
        _ = try await store.photoStore.importPhoto(image)
        _ = try await store.documentStore.importData(image)
        let count = try protectedItemCount(root)
        XCTAssertGreaterThan(count, 6)
        XCTAssertEqual(try root.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, false)
        XCTAssertEqual(try String(contentsOf: legacy, encoding: .utf8), "legacy")
    }

    private func protectedItemCount(_ root: URL) throws -> Int {
        let urls = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        var count = 0
        for case let url as URL in urls {
            #if !targetEnvironment(simulator)
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            #endif
            #if !targetEnvironment(simulator)
                XCTAssertEqual(attributes[.protectionKey] as? FileProtectionType, .complete, url.lastPathComponent)
            #endif
            count += 1
        }
        return count
    }

    func testCompleteProtectionMetadataOnPhysicalDevice() async throws {
        #if targetEnvironment(simulator)
            throw XCTSkip("Simulator does not expose NSFileProtectionKey. Run on an iPhone with a device passcode.")
        #else
            try await testExistingAndNewCollectionFilesRemainReadableAndKeepBackup()
        #endif
    }

    func testProtectionLifecycleCanRecoverAfterUnlockNotification() {
        let state = ProtectedDataState()
        NotificationCenter.default.post(name: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil)
        XCTAssertFalse(state.isAvailable)
        NotificationCenter.default.post(name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
        XCTAssertTrue(state.isAvailable)
    }
}
