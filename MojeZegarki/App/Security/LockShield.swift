import SwiftUI

/// A separate window also covers presented sheets, document viewers and app-switcher snapshots.
struct LockShield: UIViewRepresentable {
    let lock: AppLock
    // Explicit values make SwiftUI observe changes outside the UIKit coordinator.
    let enabled: Bool
    let isLocked: Bool
    var isBusy = false
    var dataAvailable = true

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.isUserInteractionEnabled = false
        view.onWindowChanged = { [weak coordinator = context.coordinator] window in coordinator?.attach(to: window) }
        return view
    }
    /// Synchronizes the coordinator with SwiftUI before updating the shield for this window.
    func updateUIView(_ view: AnchorView, context: Context) {
        context.coordinator.lock = lock
        context.coordinator.dataAvailable = dataAvailable
        context.coordinator.attach(to: view.window)
    }
    /// Disconnects the anchor before restoring the underlying window.
    static func dismantleUIView(_ uiView: AnchorView, coordinator: Coordinator) {
        uiView.onWindowChanged = nil
        coordinator.detach()
    }

    final class AnchorView: UIView {
        var onWindowChanged: ((UIWindow?) -> Void)?
        override func layoutSubviews() {
            super.layoutSubviews()
            onWindowChanged?(window)
        }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            onWindowChanged?(window)
        }
    }

    @MainActor final class Coordinator: NSObject {
        var shield: UIWindow?
        weak var originalWindow: UIWindow?
        var lock: AppLock? {
            didSet {
                if oldValue !== lock {
                    cancelUnlock()
                    needsUnlock = true
                }
            }
        }
        var dataAvailable = true {
            didSet {
                if !dataAvailable {
                    cancelUnlock()
                    needsUnlock = true
                }
            }
        }
        private var needsUnlock = true
        private var shieldObscured: Bool?
        private weak var displayedLock: AppLock?
        private var originalAccessibilityHidden: Bool?
        private var unlockTask: Task<Void, Never>?
        private var unlockID: UUID?
        private var sceneObscured = false

        /// Observes scene transitions so the shield can react before UIKit changes activation state.
        override init() {
            super.init()
            NotificationCenter.default.addObserver(
                self, selector: #selector(sceneChanged(_:)), name: UIScene.didActivateNotification, object: nil)
            NotificationCenter.default.addObserver(
                self, selector: #selector(sceneChanged(_:)), name: UIScene.willDeactivateNotification, object: nil)
            NotificationCenter.default.addObserver(
                self, selector: #selector(sceneChanged(_:)), name: UIScene.didEnterBackgroundNotification, object: nil)
        }

        deinit { unlockTask?.cancel() }

        /// Obscures private content synchronously on deactivation and relocks it on entry to the background.
        @objc private func sceneChanged(_ notification: Notification) {
            guard let scene = notification.object as? UIWindowScene, scene === originalWindow?.windowScene else {
                return
            }
            sceneObscured = notification.name != UIScene.didActivateNotification
            if notification.name == UIScene.willDeactivateNotification {
                originalWindow?.endEditing(true)
                if lock?.isBusy != true {
                    cancelUnlock()
                    needsUnlock = true
                }
            }
            if notification.name == UIScene.didEnterBackgroundNotification {
                cancelUnlock()
                needsUnlock = true
                lock?.lock()
            }
            // willDeactivate arrives before activationState changes: obscure synchronously.
            update(obscured: notification.name != UIScene.didActivateNotification)
            if notification.name == UIScene.didActivateNotification { unlockIfNeeded() }
        }

        /// Tracks the hosting window and creates a shield above its sheets in the same scene.
        func attach(to originalWindow: UIWindow?) {
            guard let originalWindow, let scene = originalWindow.windowScene else {
                detach()
                return
            }
            if self.originalWindow !== originalWindow {
                detach()
                originalAccessibilityHidden = originalWindow.accessibilityElementsHidden
                self.originalWindow = originalWindow
                sceneObscured = scene.activationState != .foregroundActive
            }
            if shield?.windowScene !== scene {
                shield?.isHidden = true
                shield = nil
                shieldObscured = nil
            }
            if shield == nil {
                let window = UIWindow(windowScene: scene)
                window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
                window.backgroundColor = .systemBackground
                shield = window
            }
            update(obscured: sceneObscured || scene.activationState != .foregroundActive)
            if scene.activationState == .foregroundActive { unlockIfNeeded() }
        }

        /// Starts at most one automatic unlock per eligible activation.
        private func unlockIfNeeded() {
            guard dataAvailable, !sceneObscured, needsUnlock, let lock else { return }
            // Consume this activation even when protection is disabled or already unlocked.
            // Otherwise enabling protection later makes "Lock now" immediately authenticate again.
            guard lock.enabled, lock.isLocked else {
                needsUnlock = false
                return
            }
            guard !lock.isBusy else { return }
            needsUnlock = false
            let id = UUID()
            unlockID = id
            unlockTask = Task { [weak self, weak lock] in
                guard !Task.isCancelled, self?.dataAvailable == true, self?.sceneObscured == false,
                    self?.originalWindow?.windowScene?.activationState == .foregroundActive, let lock
                else { return }
                await lock.unlock()
                if self?.unlockID == id {
                    self?.unlockTask = nil
                    self?.unlockID = nil
                }
            }
        }

        private func cancelUnlock() {
            unlockTask?.cancel()
            unlockTask = nil
            unlockID = nil
        }

        /// Cancels queued authentication and restores the original accessibility state.
        func detach() {
            cancelUnlock()
            needsUnlock = true
            if let originalAccessibilityHidden {
                originalWindow?.accessibilityElementsHidden = originalAccessibilityHidden
            }
            originalWindow = nil
            originalAccessibilityHidden = nil
            shield?.isHidden = true
            shield = nil
            shieldObscured = nil
            displayedLock = nil
        }

        /// Keeps the shield and the underlying window’s accessibility exposure in sync.
        private func update(obscured: Bool) {
            guard let lock, let scene = originalWindow?.windowScene else { return }
            let visible = !dataAvailable || (lock.enabled && (lock.isLocked || obscured))
            originalWindow?.accessibilityElementsHidden = visible || (originalAccessibilityHidden ?? false)
            if visible {
                let concealed = obscured || !dataAvailable
                if let controller = shield?.rootViewController as? UIHostingController<LockScreen> {
                    if shieldObscured != concealed || displayedLock !== lock {
                        controller.rootView = LockScreen(lock: lock, obscured: concealed)
                    }
                } else {
                    let controller = UIHostingController(rootView: LockScreen(lock: lock, obscured: concealed))
                    controller.view.backgroundColor = .systemBackground
                    controller.view.accessibilityViewIsModal = true
                    shield?.rootViewController = controller
                }
                shieldObscured = concealed
                displayedLock = lock
            }
            shield?.frame = scene.coordinateSpace.bounds
            shield?.isHidden = !visible
        }
    }
}
