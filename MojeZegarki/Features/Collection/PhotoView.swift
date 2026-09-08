import SwiftUI

struct PhotoView: View {
    let photo: PhotoDraft?
    let store: PhotoStore
    var thumbnail = true
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(uiColor: .secondarySystemGroupedBackground)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: thumbnail ? .fill : .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    Image(systemName: "watch.analog")
                        .font(.system(size: min(geometry.size.width / 3, 60), weight: .ultraLight))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityHidden(true)
        .task(id: photo?.id) {
            image = nil
            if let photo, let data = await store.data(for: photo, thumbnail: thumbnail), !Task.isCancelled {
                image = UIImage(data: data)
            }
        }
    }
}
