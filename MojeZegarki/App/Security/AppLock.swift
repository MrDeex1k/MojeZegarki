import LocalAuthentication
import Observation

@MainActor @Observable
final class AppLock {
    private(set) var enabled: Bool
    private(set) var isLocked: Bool
    private(set) var isBusy = false
    var error: String?
    private let defaults: UserDefaults
    private let authenticator: any DeviceAuthenticating
    private var generation = 0

    init(
        defaults: UserDefaults = .standard, authenticator: any DeviceAuthenticating = SystemDeviceAuthenticator()
    ) {
        self.defaults = defaults
        self.authenticator = authenticator
        let initiallyEnabled = defaults.bool(forKey: "appLockEnabled")
        enabled = initiallyEnabled
        isLocked = initiallyEnabled
    }

    /// Refreshes the saved setting and discards authentication that started under the previous setting.
    func reloadPreference() {
        generation += 1
        authenticator.invalidate()
        error = nil
        enabled = defaults.bool(forKey: "appLockEnabled")
        isLocked = enabled
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

    /// Accepts a result only from an uncancelled request for the current lock generation.
    private func verify() async -> Bool {
        guard !Task.isCancelled else { return false }
        isBusy = true
        error = nil
        let request = generation
        defer { isBusy = false }
        do {
            let success = try await authenticator.authenticate(
                reason: String(localized: "Authenticate to access your private collection."))
            return success && generation == request && !Task.isCancelled
        } catch {
            guard generation == request, !Task.isCancelled, !(error is CancellationError) else { return false }
            if let authError = error as? LAError, [.userCancel, .systemCancel, .appCancel].contains(authError.code) {
                return false
            }
            self.error = String(
                localized:
                    "Authentication could not be completed. Make sure a device passcode is configured and try again.")
            return false
        }
    }
}
