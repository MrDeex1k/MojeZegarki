import XCTest

@testable import MojeZegarki

private actor RemovalRecorder {
    private(set) var ids: Set<UUID> = []
    func remove(_ id: UUID) { ids.insert(id) }
}

@MainActor
final class DraftAssetSessionTests: XCTestCase {
    func testCommitKeepsRetainedAssetAndRemovesReplacedAndUnusedAssets() async {
        let recorder = RemovalRecorder()
        let retained = UUID()
        let unused = UUID()
        let old = UUID()
        let session = DraftAssetSession { await recorder.remove($0) }
        _ = await session.stage(retained)
        _ = await session.stage(unused)
        await session.commit(retaining: [retained], replacing: [old])
        let removed = await recorder.ids
        XCTAssertEqual(removed, [unused, old])
    }

    func testClosingDraftReleasesOnlyItsStagedFiles() async {
        let recorder = RemovalRecorder()
        let id = UUID()
        var session: DraftAssetSession? = DraftAssetSession { await recorder.remove($0) }
        _ = await session?.stage(id)
        weak let weakSession = session
        session = nil
        for _ in 0..<100 {
            if await recorder.ids.contains(id) { break }
            await Task.yield()
        }
        XCTAssertNil(weakSession)
        let removed = await recorder.ids
        XCTAssertEqual(removed, [id])
    }

    func testReappearingCommittedDocumentDoesNotReclaimOrDeleteItsFile() async {
        let recorder = RemovalRecorder()
        let id = UUID()
        var session: DraftAssetSession? = DraftAssetSession { await recorder.remove($0) }
        session?.claim(id)
        await session?.commit(retaining: [id])
        session?.claim(id)
        session = nil
        for _ in 0..<10 { await Task.yield() }
        let removed = await recorder.ids
        XCTAssertTrue(removed.isEmpty)
    }

    func testCancelledImportCleansLateResultWithoutStagingIt() async {
        let recorder = RemovalRecorder()
        let id = UUID()
        let session = DraftAssetSession { await recorder.remove($0) }
        let task = Task { await session.stage(id) }
        task.cancel()
        let staged = await task.value
        XCTAssertFalse(staged)
        let removed = await recorder.ids
        XCTAssertEqual(removed, [id])
    }
}
