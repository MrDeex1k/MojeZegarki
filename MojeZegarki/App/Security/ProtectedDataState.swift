import Observation
import UIKit

@MainActor @Observable
final class ProtectedDataState: NSObject {
    private(set) var isAvailable: Bool

    override init() {
        isAvailable = UIApplication.shared.isProtectedDataAvailable
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(willBecomeUnavailable),
            name: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(didBecomeAvailable),
            name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(refresh),
            name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @objc private func willBecomeUnavailable() {
        isAvailable = false
        ImageLoader.clearCache()
    }

    @objc private func didBecomeAvailable() { isAvailable = true }

    @objc private func refresh() {
        let available = UIApplication.shared.isProtectedDataAvailable
        guard available != isAvailable else { return }
        isAvailable = available
        if !available { ImageLoader.clearCache() }
    }
}
