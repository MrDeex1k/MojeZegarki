import SwiftUI

struct ZoomableDocumentImage: UIViewRepresentable {
    let image: UIImage
    @Binding var zoom: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(zoom: $zoom) }

    func makeUIView(context: Context) -> ImageScrollView {
        let view = ImageScrollView(image: image)
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ view: ImageScrollView, context: Context) {
        context.coordinator.zoom = $zoom
        if abs(view.zoomScale - zoom) > 0.01 { view.setZoomScale(zoom, animated: false) }
        view.imageView.accessibilityValue = Double(zoom).formatted(.percent.precision(.fractionLength(0)))
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var zoom: Binding<CGFloat>
        init(zoom: Binding<CGFloat>) { self.zoom = zoom }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { (scrollView as? ImageScrollView)?.imageView }
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            if abs(zoom.wrappedValue - scrollView.zoomScale) > 0.01 { zoom.wrappedValue = scrollView.zoomScale }
        }
    }

    final class ImageScrollView: UIScrollView {
        let imageView: UIImageView
        private var viewportSize = CGSize.zero
        init(image: UIImage) {
            imageView = UIImageView(image: image)
            super.init(frame: .zero)
            imageView.contentMode = .scaleAspectFit
            imageView.isAccessibilityElement = true
            imageView.accessibilityLabel = String(localized: "Document preview")
            addSubview(imageView)
            minimumZoomScale = 1
            maximumZoomScale = 5
        }
        required init?(coder: NSCoder) { nil }
        override func layoutSubviews() {
            super.layoutSubviews()
            let size = bounds.size
            guard size.width > 0, size.height > 0 else { return }
            if viewportSize != size {
                let scale = zoomScale
                let oldSize = viewportSize
                let center = CGPoint(
                    x: (contentOffset.x + oldSize.width / 2) / max(contentSize.width, 1),
                    y: (contentOffset.y + oldSize.height / 2) / max(contentSize.height, 1))
                viewportSize = size
                setZoomScale(1, animated: false)
                imageView.frame = CGRect(origin: .zero, size: size)
                contentSize = size
                setZoomScale(scale, animated: false)
                contentOffset = CGPoint(
                    x: min(
                        max(center.x * contentSize.width - size.width / 2, 0), max(contentSize.width - size.width, 0)),
                    y: min(
                        max(center.y * contentSize.height - size.height / 2, 0),
                        max(contentSize.height - size.height, 0)))
            }
        }
    }
}
