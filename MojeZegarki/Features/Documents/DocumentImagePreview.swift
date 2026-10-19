import SwiftUI

struct DocumentImagePreview: View {
    let image: UIImage
    @State private var zoom: CGFloat = 1

    var body: some View {
        VStack(spacing: 0) {
            ZoomableDocumentImage(image: image, zoom: $zoom)
            HStack {
                Button("Zoom out", systemImage: "minus.magnifyingglass") { zoom = max(1, zoom - 0.5) }
                    .frame(minWidth: 44, minHeight: 44).disabled(zoom <= 1)
                Button("Reset zoom") { zoom = 1 }.frame(minHeight: 44)
                Button("Zoom in", systemImage: "plus.magnifyingglass") { zoom = min(5, zoom + 0.5) }
                    .frame(minWidth: 44, minHeight: 44).disabled(zoom >= 5)
            }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .frame(minHeight: 44)
            .padding(.horizontal)
            .accessibilityIdentifier("document.zoomControls")
        }
    }
}
