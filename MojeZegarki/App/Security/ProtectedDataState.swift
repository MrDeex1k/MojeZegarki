import Observation
import UIKit

@MainActor @Observable
final class ProtectedDataState: NSObject {
    private(set) var isAvailable: Bool
    private let readAvailability: @MainActor () -> Bool

    /// Observes protected-data events and reads current availability again when the application activates.
    init(
        readAvailability: @escaping @MainActor () -> Bool = { UIApplication.shared.isProtectedDataAvailable },
        notifications: NotificationCenter = .default
    ) {
        self.readAvailability = readAvailability
        isAvailable = readAvailability()
        super.init()
        notifications.addObserver(
            self, selector: #selector(willBecomeUnavailable),
            name: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil)
        notifications.addObserver(
            self, selector: #selector(didBecomeAvailable),
            name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
        notifications.addObserver(
            self, selector: #selector(refresh),
            name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    /// Discards decoded thumbnails and pending image results as protected data locks.
    @objc private func willBecomeUnavailable() {
        isAvailable = false
        ImageLoader.clearCache()
    }

    /// Lets interrupted image loads retry once protected files are accessible again.
    @objc private func didBecomeAvailable() {
        isAvailable = true
        ImageLoader.access.retryLoads()
    }

    /// Retries failed reads on activation even when protected data was already available.
    @objc private func refresh() {
        let available = readAvailability()
        if available != isAvailable {
            isAvailable = available
            if !available { ImageLoader.clearCache() }
        }
        // A previous read can fail transiently even when data was already available.
        if available { ImageLoader.access.retryLoads() }
    }
}
