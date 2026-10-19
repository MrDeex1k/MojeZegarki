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
            if zoomScale == 1 {
                imageView.frame = bounds
                contentSize = bounds.size
            }
        }
    }
}
