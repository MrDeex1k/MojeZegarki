import SwiftUI

struct WearScrollAnchor: UIViewRepresentable {
    let behavior: WearScrollBehavior

    func makeUIView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.behavior = behavior
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: AnchorView, context: Context) {
        uiView.behavior = behavior
        // Apply after SwiftUI finishes updating the containing list.
        Task { @MainActor [weak uiView] in
            await Task.yield()
            uiView?.attach()
        }
    }

    final class AnchorView: UIView {
        weak var behavior: WearScrollBehavior?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            attach()
        }

        func attach() {
            var ancestor = superview
            while let view = ancestor {
                if let scrollView = view as? UIScrollView {
                    behavior?.attach(to: scrollView)
                    return
                }
                ancestor = view.superview
            }
        }
    }
}
