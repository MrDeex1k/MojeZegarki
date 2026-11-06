import SwiftUI
import XCTest

@testable import MojeZegarki

@MainActor final class SecurityLifecycleTests: XCTestCase {
    @MainActor private final class Authenticator: DeviceAuthenticating {
        var calls = 0
        func authenticate(reason: String) async throws -> Bool {
            calls += 1
            return true
        }
        func invalidate() {}
    }

    /// Attaches a shield to a real window so tests can drive scene notifications and accessibility state.
    private func fixture(hidden: Bool = false) throws -> (LockShield.Coordinator, UIWindow, AppLock, Authenticator) {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        XCTAssertEqual(scene.activationState, .foregroundActive)
        let window = UIWindow(windowScene: scene)
        window.accessibilityElementsHidden = hidden
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(true, forKey: "appLockEnabled")
        let auth = Authenticator()
        let lock = AppLock(defaults: defaults, authenticator: auth)
        let coordinator = LockShield.Coordinator()
        coordinator.lock = lock
        coordinator.attach(to: window)
        return (coordinator, window, lock, auth)
    }

    func testBackgroundCancelsQueuedAutomaticUnlock() async throws {
        let (coordinator, window, lock, auth) = try fixture()
        defer { coordinator.detach() }
        NotificationCenter.default.post(name: UIScene.didEnterBackgroundNotification, object: window.windowScene)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(auth.calls, 0)
        XCTAssertTrue(lock.isLocked)
        XCTAssertTrue(window.accessibilityElementsHidden)
        XCTAssertFalse(coordinator.shield?.isHidden ?? true)
    }

    func testUnavailableDataCancelsQueuedAutomaticUnlock() async throws {
        let (coordinator, window, lock, auth) = try fixture()
        defer { coordinator.detach() }
        coordinator.dataAvailable = false
        coordinator.attach(to: window)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(auth.calls, 0)
        XCTAssertTrue(lock.isLocked)
    }

    /// Simulates layout after willDeactivate but before the scene reports its new state.
    func testLayoutCannotUncoverShieldBeforeSceneStateChanges() async throws {
        let (coordinator, window, _, auth) = try fixture()
        defer { coordinator.detach() }
        NotificationCenter.default.post(name: UIScene.willDeactivateNotification, object: window.windowScene)
        // UIKit updates activationState after willDeactivate, and layout may run in between.
        coordinator.attach(to: window)
        let controller = try XCTUnwrap(coordinator.shield?.rootViewController as? UIHostingController<LockScreen>)
        XCTAssertTrue(controller.rootView.obscured)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(auth.calls, 0)
    }

    func testDetachCancelsUnlockAndRestoresPriorAccessibilityState() async throws {
        for hidden in [false, true] {
            let (coordinator, window, lock, auth) = try fixture(hidden: hidden)
            coordinator.attach(to: nil)
            for _ in 0..<20 { await Task.yield() }
            XCTAssertEqual(auth.calls, 0)
            XCTAssertTrue(lock.isLocked)
            XCTAssertNil(coordinator.shield)
            XCTAssertEqual(window.accessibilityElementsHidden, hidden)
        }
    }

    func testReplacingLockUpdatesThePresentedShield() throws {
        let (coordinator, window, _, _) = try fixture()
        defer { coordinator.detach() }
        coordinator.dataAvailable = false
        let replacement = AppLock(defaults: UserDefaults(suiteName: UUID().uuidString)!, authenticator: Authenticator())
        coordinator.lock = replacement
        coordinator.attach(to: window)
        let controller = try XCTUnwrap(coordinator.shield?.rootViewController as? UIHostingController<LockScreen>)
        XCTAssertTrue(controller.rootView.lock === replacement)
    }

    func testManualLockAfterEnablingProtectionDoesNotAutomaticallyReopen() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let auth = Authenticator()
        let lock = AppLock(defaults: UserDefaults(suiteName: UUID().uuidString)!, authenticator: auth)
        let coordinator = LockShield.Coordinator()
        defer { coordinator.detach() }
        coordinator.lock = lock
        coordinator.attach(to: window)
        await lock.setEnabled(true)
        coordinator.attach(to: window)
        lock.lock()
        coordinator.attach(to: window)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(auth.calls, 1)
        XCTAssertTrue(lock.isLocked)
        XCTAssertFalse(coordinator.shield?.isHidden ?? true)
    }
}
