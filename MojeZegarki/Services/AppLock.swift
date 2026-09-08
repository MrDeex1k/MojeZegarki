import Foundation
import LocalAuthentication
import Observation

@MainActor
protocol DeviceAuthenticating {
    func authenticate(reason: String) async throws -> Bool
    func invalidate()
}

@MainActor
final class SystemDeviceAuthenticator: DeviceAuthenticating {
    private var context: LAContext?
    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        self.context = context
        defer { self.context = nil }
        var failure: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &failure) else {
            throw failure ?? NSError(domain: LAError.errorDomain, code: LAError.passcodeNotSet.rawValue)
        }
        return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
    }
    func invalidate() { context?.invalidate() }
}

@MainActor @Observable
final class AppLock {
    private(set) var enabled: Bool
    private(set) var isLocked: Bool
    private(set) var isBusy = false
    var error: String?
    private let defaults: UserDefaults
    private let authenticator: any DeviceAuthenticating
    private var generation = 0

    init(defaults: UserDefaults = .standard, authenticator: any DeviceAuthenticating = SystemDeviceAuthenticator()) {
        self.defaults = defaults
        self.authenticator = authenticator
        let initiallyEnabled = defaults.bool(forKey: "appLockEnabled")
        enabled = initiallyEnabled
        isLocked = initiallyEnabled
    }

    func setEnabled(_ value: Bool) async {
        guard value != enabled, !isBusy else { return }
        if await verify() {
            enabled = value
            isLocked = false
            defaults.set(value, forKey: "appLockEnabled")
        }
    }

    func unlock() async {
        guard enabled, isLocked, !isBusy else { return }
        if await verify() { isLocked = false }
    }

    func lock() {
        generation += 1
        if enabled { isLocked = true }
        authenticator.invalidate()
    }

    private func verify() async -> Bool {
        isBusy = true
        error = nil
        let request = generation
        defer { isBusy = false }
        do {
            let success = try await authenticator.authenticate(reason: String(localized: "Authenticate to access your private collection."))
            return success && generation == request
        } catch {
            guard generation == request else { return false }
            if let authError = error as? LAError, [.userCancel, .systemCancel, .appCancel].contains(authError.code) { return false }
            self.error = String(localized: "Authentication could not be completed. Make sure a device passcode is configured and try again.")
            return false
        }
    }
}
