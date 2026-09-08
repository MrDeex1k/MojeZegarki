import XCTest
import LocalAuthentication
@testable import MojeZegarki

@MainActor
private final class FakeAuthenticator: DeviceAuthenticating {
    var success = true
    var failure: Error?
    var calls = 0
    var invalidations = 0
    var suspended = false
    var continuation: CheckedContinuation<Bool, any Error>?
    func authenticate(reason: String) async throws -> Bool {
        calls += 1
        if suspended { return try await withCheckedThrowingContinuation { continuation = $0 } }
        if let failure { throw failure }
        return success
    }
    func invalidate() { invalidations += 1 }
}

@MainActor
final class AppLockTests: XCTestCase {
    func testEnableUnlockAndDisableRequireAuthentication() async throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let auth = FakeAuthenticator()
        let lock = AppLock(defaults: defaults, authenticator: auth)
        XCTAssertFalse(lock.enabled)
        auth.success = false
        await lock.setEnabled(true)
        XCTAssertFalse(lock.enabled)
        auth.success = true
        await lock.setEnabled(true)
        XCTAssertTrue(defaults.bool(forKey: "appLockEnabled"))
        lock.lock()
        XCTAssertTrue(lock.isLocked)
        auth.failure = LAError(.userCancel)
        await lock.unlock()
        XCTAssertTrue(lock.isLocked)
        XCTAssertNil(lock.error)
        auth.failure = nil
        await lock.unlock()
        XCTAssertFalse(lock.isLocked)
        auth.success = false
        await lock.setEnabled(false)
        XCTAssertTrue(lock.enabled)
        XCTAssertTrue(AppLock(defaults: defaults, authenticator: auth).isLocked)
        auth.success = true
        await lock.setEnabled(false)
        XCTAssertFalse(lock.enabled)
        XCTAssertFalse(defaults.bool(forKey: "appLockEnabled"))
    }

    func testBackgroundInvalidatesPendingSuccessAndDeduplicatesRequests() async throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(true, forKey: "appLockEnabled")
        let auth = FakeAuthenticator()
        auth.suspended = true
        let lock = AppLock(defaults: defaults, authenticator: auth)
        let pending = Task { await lock.unlock() }
        for _ in 0..<100 where auth.continuation == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        guard let continuation = auth.continuation else {
            pending.cancel()
            XCTFail("AppLock did not request authentication within one second")
            return
        }
        await lock.unlock()
        XCTAssertEqual(auth.calls, 1)
        lock.lock()
        continuation.resume(returning: true)
        await pending.value
        XCTAssertTrue(lock.isLocked)
        XCTAssertFalse(lock.isBusy)
        XCTAssertEqual(auth.invalidations, 1)
    }
}
