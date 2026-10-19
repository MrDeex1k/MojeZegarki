import SwiftUI

/// A separate window also covers presented sheets, document viewers and app-switcher snapshots.
struct LockShield: UIViewRepresentable {
    let lock: AppLock
    // Explicit values make SwiftUI observe changes outside the UIKit coordinator.
    let enabled: Bool
    let isLocked: Bool
    var dataAvailable = true

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.isUserInteractionEnabled = false
        view.onWindowChanged = { [weak coordinator = context.coordinator] window in coordinator?.attach(to: window) }
        return view
    }
    func updateUIView(_ view: AnchorView, context: Context) {
        context.coordinator.lock = lock
        context.coordinator.dataAvailable = dataAvailable
        context.coordinator.attach(to: view.window)
    }
    static func dismantleUIView(_ uiView: AnchorView, coordinator: Coordinator) {
        coordinator.shield?.isHidden = true
        coordinator.originalWindow?.accessibilityElementsHidden = false
        coordinator.shield = nil
    }

    final class AnchorView: UIView {
        var onWindowChanged: ((UIWindow?) -> Void)?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            onWindowChanged?(window)
        }
    }

    @MainActor final class Coordinator: NSObject {
        var shield: UIWindow?
        weak var originalWindow: UIWindow?
        var lock: AppLock?
        var dataAvailable = true
        private var needsUnlock = true

        override init() {
            super.init()
            NotificationCenter.default.addObserver(
                self, selector: #selector(sceneChanged(_:)), name: UIScene.didActivateNotification, object: nil)
            NotificationCenter.default.addObserver(
                self, selector: #selector(sceneChanged(_:)), name: UIScene.willDeactivateNotification, object: nil)
            NotificationCenter.default.addObserver(
                self, selector: #selector(sceneChanged(_:)), name: UIScene.didEnterBackgroundNotification, object: nil)
        }

        @objc private func sceneChanged(_ notification: Notification) {
            guard let scene = notification.object as? UIWindowScene, scene === originalWindow?.windowScene else {
                return
            }
            if notification.name == UIScene.willDeactivateNotification { originalWindow?.endEditing(true) }
            if notification.name == UIScene.didEnterBackgroundNotification {
                needsUnlock = true
                lock?.lock()
            }
            // willDeactivate arrives before activationState changes: obscure synchronously.
            update(obscured: notification.name != UIScene.didActivateNotification)
            if notification.name == UIScene.didActivateNotification { unlockIfNeeded() }
        }

        func attach(to originalWindow: UIWindow?) {
            guard let scene = originalWindow?.windowScene else { return }
            self.originalWindow = originalWindow
            if shield == nil {
                let window = UIWindow(windowScene: scene)
                window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
                window.backgroundColor = .systemBackground
                shield = window
            }
            update(obscured: scene.activationState != .foregroundActive)
            if scene.activationState == .foregroundActive { unlockIfNeeded() }
        }

        private func unlockIfNeeded() {
            guard dataAvailable, needsUnlock, let lock, lock.enabled, lock.isLocked else { return }
            needsUnlock = false
            Task { await lock.unlock() }
        }

        private func update(obscured: Bool) {
            guard let lock, let scene = originalWindow?.windowScene else { return }
            let visible = !dataAvailable || (lock.enabled && (lock.isLocked || obscured))
            originalWindow?.accessibilityElementsHidden = visible
            if visible {
                let controller = UIHostingController(
                    rootView: LockScreen(lock: lock, obscured: obscured || !dataAvailable))
                controller.view.backgroundColor = .systemBackground
                controller.view.accessibilityViewIsModal = true
                shield?.rootViewController = controller
                shield?.frame = scene.coordinateSpace.bounds
            }
            shield?.isHidden = !visible
        }
    }
}
