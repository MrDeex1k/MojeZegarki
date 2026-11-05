import XCTest

@testable import MojeZegarki

@MainActor final class StartupTests: XCTestCase {
    @MainActor private final class Gate {
        private var started = false
        private var startWaiter: CheckedContinuation<Void, Never>?
        private var completion: CheckedContinuation<Void, Never>?
        func enter() async {
            started = true
            startWaiter?.resume()
            startWaiter = nil
            await withCheckedContinuation { completion = $0 }
        }
        func waitForStart() async {
            if !started { await withCheckedContinuation { startWaiter = $0 } }
        }
        func finish() {
            completion?.resume()
            completion = nil
        }
    }

    func testUnlockDuringCancelledAttemptStartsReplacementWithoutOverlap() async {
        let gate = Gate()
        var calls = 0
        var active = 0
        var maximumActive = 0
        let startup = StartupController<Int> {
            calls += 1
            active += 1
            maximumActive = max(maximumActive, active)
            defer { active -= 1 }
            if calls == 1 { await gate.enter() }
            return calls
        }
        startup.setDataAvailable(true)
        await gate.waitForStart()
        startup.setDataAvailable(false)
        startup.setDataAvailable(true)
        XCTAssertEqual(calls, 1)
        gate.finish()
        await startup.waitUntilSettled()
        XCTAssertEqual(startup.resource, 2)
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(maximumActive, 1)
        XCTAssertNil(startup.failure)
    }

    func testUnavailableDataDoesNotOpenAndReadyResourceSurvivesLocking() async {
        var calls = 0
        let startup = StartupController<Int> {
            calls += 1
            return 42
        }
        startup.setDataAvailable(false)
        await startup.waitUntilSettled()
        XCTAssertEqual(calls, 0)
        startup.setDataAvailable(true)
        await startup.waitUntilSettled()
        startup.setDataAvailable(false)
        startup.setDataAvailable(true)
        await startup.waitUntilSettled()
        XCTAssertEqual(startup.resource, 42)
        XCTAssertEqual(calls, 1)
    }

    func testFailureRequiresExplicitRetryAndKeepsUsefulCategory() async {
        var calls = 0
        let startup = StartupController<Int> {
            calls += 1
            if calls == 1 { throw CocoaError(.fileWriteOutOfSpace) }
            return 42
        }
        startup.setDataAvailable(true)
        await startup.waitUntilSettled()
        XCTAssertEqual(startup.failure?.kind, .storageFull)
        startup.setDataAvailable(true)
        await startup.waitUntilSettled()
        XCTAssertEqual(calls, 1)
        startup.retry()
        await startup.waitUntilSettled()
        XCTAssertEqual(startup.resource, 42)
        XCTAssertNil(startup.failure)
    }

    func testCancelledErrorWhileLockedIsNotShownAndUnlockCanRetry() async {
        let gate = Gate()
        var calls = 0
        let startup = StartupController<Int> {
            calls += 1
            if calls == 1 {
                await gate.enter()
                throw CocoaError(.fileReadNoPermission)
            }
            return 42
        }
        startup.setDataAvailable(true)
        await gate.waitForStart()
        startup.setDataAvailable(false)
        gate.finish()
        await startup.waitUntilSettled()
        XCTAssertNil(startup.failure)
        XCTAssertNil(startup.resource)
        startup.setDataAvailable(true)
        await startup.waitUntilSettled()
        XCTAssertEqual(startup.resource, 42)
    }

    func testCleanupFailureStillPublishesOpenedCollection() async throws {
        let store = try CollectionStore(inMemory: true)
        let bootstrap = CollectionBootstrap(
            configuration: AppLaunchConfiguration(arguments: []),
            openStore: { _ in store },
            reconcile: { _ in throw CocoaError(.fileWriteNoPermission) })
        let startup = StartupController(load: bootstrap.load)
        startup.setDataAvailable(true)
        await startup.waitUntilSettled()
        XCTAssertTrue(startup.resource === store)
        XCTAssertNil(startup.failure)
    }

    func testLaunchFlagsRequireUITestingAndNestedErrorsAreClassified() {
        XCTAssertNil(AppLaunchConfiguration(arguments: ["--reset-test-store"]).directory)
        XCTAssertFalse(AppLaunchConfiguration(arguments: ["--test-dark"]).has("--test-dark"))
        let wrapped = NSError(
            domain: "Wrapper", code: 1,
            userInfo: [
                NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))
            ])
        XCTAssertEqual(StartupFailure(error: wrapped).kind, .storageFull)
        XCTAssertEqual(StartupFailure(error: CocoaError(.fileReadNoPermission)).kind, .unavailable)
        XCTAssertEqual(StartupFailure(error: CocoaError(.fileReadCorruptFile)).kind, .other)
    }
}
