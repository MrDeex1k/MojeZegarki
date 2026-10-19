import SwiftUI

/// Keep normal scrolling, but prevent elastic overscroll in the watch's wear sheet.
/// SwiftUI's basedOnSize still bounces when content exceeds the viewport by a few points.
@MainActor final class WearScrollBehavior {
    private weak var scrollView: UIScrollView?
    private var observation: NSKeyValueObservation?

    func attach(to scrollView: UIScrollView) {
        guard self.scrollView !== scrollView else {
            scrollView.bounces = false
            return
        }
        observation = nil
        self.scrollView = scrollView
        scrollView.bounces = false
        // SwiftUI can reapply its scroll configuration after selection or layout changes.
        // Retain this observation for the view's lifetime, including when the anchor's row is recycled.
        observation = scrollView.observe(\.bounces, options: [.new]) { scrollView, _ in
            MainActor.assumeIsolated {
                if scrollView.bounces { scrollView.bounces = false }
            }
        }
    }
}
