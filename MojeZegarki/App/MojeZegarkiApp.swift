import SwiftUI

@main
struct MojeZegarkiApp: App {
    @State private var startup = StartupController(load: CollectionBootstrap().load)
    private let configuration = AppLaunchConfiguration()
    @State private var protectedData = ProtectedDataState()
    @State private var lock: AppLock?

    @MainActor private func makeLock() -> AppLock {
        var defaults = UserDefaults.standard
        #if DEBUG
            if configuration.isUITesting,
                let testDefaults = UserDefaults(suiteName: "CollectionUITests")
            {
                defaults = testDefaults
                if configuration.has("--reset-test-store") {
                    defaults.removePersistentDomain(forName: "CollectionUITests")
                }
                if configuration.has("--test-lock-enabled") {
                    defaults.set(true, forKey: "appLockEnabled")
                }
            }
            if configuration.has("--test-authentication-cancelled") {
                return AppLock(defaults: defaults, authenticator: UITestFixtures.CancelledAuthenticator())
            }
        #endif
        return AppLock(defaults: defaults)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let store = startup.resource, let lock {
                    RootView(store: store, lock: lock).modelContainer(store.container)
                        .disabled(!protectedData.isAvailable)
                        .accessibilityHidden(!protectedData.isAvailable)
                } else if !protectedData.isAvailable {
                    ContentUnavailableView(
                        "Unlock your iPhone", systemImage: "lock.shield",
                        description: Text("Your collection will be available after you unlock this device."))
                } else if let failure = startup.failure {
                    ContentUnavailableView {
                        Label("Could not open collection", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text(failure.message)
                    } actions: {
                        Button("Try again") { startup.retry() }
                    }
                } else {
                    ProgressView("Opening collection…")
                }
            }
            .preferredColorScheme(testColorScheme)
            .tint(Color("AccentColor"))
            .background {
                if let lock {
                    LockShield(
                        lock: lock, enabled: lock.enabled, isLocked: lock.isLocked,
                        dataAvailable: protectedData.isAvailable
                    )
                    .frame(width: 0, height: 0)
                }
            }
            .onChange(of: protectedData.isAvailable, initial: true) {
                if protectedData.isAvailable {
                    if lock == nil { lock = makeLock() } else { lock?.reloadPreference() }
                } else {
                    lock?.lock()
                }
                startup.setDataAvailable(protectedData.isAvailable)
            }
        }
    }

    private var testColorScheme: ColorScheme? {
        #if DEBUG
            if configuration.isUITesting {
                if configuration.has("--test-dark") { return .dark }
                if configuration.has("--test-light") { return .light }
            }
        #endif
        return nil
    }

}
