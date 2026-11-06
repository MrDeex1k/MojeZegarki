import LocalAuthentication
import XCTest

@testable import MojeZegarki

@MainActor
private final class FakeAuthenticator: DeviceAuthenticating {
    var success = true
    var failure: Error?
    var calls = 0
    var invalidations = 0
    var suspended = false
    var ignoresCancellation = false
    var didSuspend: (() -> Void)?
    private(set) var continuation: CheckedContinuation<Bool, any Error>?
    func authenticate(reason: String) async throws -> Bool {
        calls += 1
        if suspended {
            if ignoresCancellation {
                return try await suspend()
            }
            return try await withTaskCancellationHandler {
                try await suspend()
            } onCancel: {
                Task { @MainActor [weak self] in
                    self?.cancelPendingAuthentication()
                }
            }
        }
        if let failure { throw failure }
        return success
    }

    private func suspend() async throws -> Bool {
        try await withCheckedThrowingContinuation {
            continuation = $0
            didSuspend?()
        }
    }

    func invalidate() { invalidations += 1 }
    func completeAuthentication(returning result: Bool) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: result)
    }
    private func cancelPendingAuthentication() {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(throwing: CancellationError())
    }
}

@MainActor
final class AppLockTests: XCTestCase {
    private func expectSuspension(of auth: FakeAuthenticator) -> XCTestExpectation {
        let started = expectation(description: "Authenticator is waiting for a response")
        auth.suspended = true
        auth.didSuspend = { started.fulfill() }
        return started
    }

    func testCancelledTaskCannotAcceptLateAuthenticationSuccess() async throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(true, forKey: "appLockEnabled")
        let auth = FakeAuthenticator()
        let started = expectSuspension(of: auth)
        auth.ignoresCancellation = true
        let lock = AppLock(defaults: defaults, authenticator: auth)
        let task = Task { await lock.unlock() }
        await fulfillment(of: [started], timeout: 2)
        task.cancel()
        auth.completeAuthentication(returning: true)
        await task.value
        XCTAssertTrue(lock.isLocked)
        XCTAssertNil(lock.error)
    }

    func testReloadInvalidatesPendingAuthentication() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(true, forKey: "appLockEnabled")
        let auth = FakeAuthenticator()
        let started = expectSuspension(of: auth)
        let lock = AppLock(defaults: defaults, authenticator: auth)
        let task = Task { await lock.unlock() }
        await fulfillment(of: [started], timeout: 2)
        guard auth.continuation != nil else {
            task.cancel()
            await task.value
            return
        }
        lock.reloadPreference()
        auth.completeAuthentication(returning: true)
        await task.value
        XCTAssertTrue(lock.isLocked)
        XCTAssertEqual(auth.invalidations, 1)
    }

    func testReloadedPreferencesRestoreEnabledLock() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let lock = AppLock(defaults: defaults, authenticator: FakeAuthenticator())
        XCTAssertFalse(lock.enabled)
        defaults.set(true, forKey: "appLockEnabled")
        lock.reloadPreference()
        XCTAssertTrue(lock.enabled)
        XCTAssertTrue(lock.isLocked)
    }

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
        let started = expectSuspension(of: auth)
        let lock = AppLock(defaults: defaults, authenticator: auth)
        let pending = Task { await lock.unlock() }
        await fulfillment(of: [started], timeout: 2)
        guard auth.continuation != nil else {
            pending.cancel()
            await pending.value
            return
        }
        await lock.unlock()
        XCTAssertEqual(auth.calls, 1)
        lock.lock()
        auth.completeAuthentication(returning: true)
        await pending.value
        XCTAssertTrue(lock.isLocked)
        XCTAssertFalse(lock.isBusy)
        XCTAssertEqual(auth.invalidations, 1)
    }

    func testCancellingPendingAuthenticationResumesContinuation() async throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(true, forKey: "appLockEnabled")
        let auth = FakeAuthenticator()
        let started = expectSuspension(of: auth)
        let lock = AppLock(defaults: defaults, authenticator: auth)
        let pending = Task { await lock.unlock() }
        await fulfillment(of: [started], timeout: 2)

        pending.cancel()
        await pending.value

        XCTAssertNil(auth.continuation)
        XCTAssertFalse(lock.isBusy)
        XCTAssertTrue(lock.isLocked)
    }
}
