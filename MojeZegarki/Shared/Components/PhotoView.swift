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
                        .foregroundStyle(Color.supportingText)
                }
            }
        }
        .accessibilityHidden(true)
        .task(id: photo?.id) {
            image = nil
            if let photo {
                let prepared = await ImageLoader.load(photo, store: store, thumbnail: thumbnail)
                if !Task.isCancelled { image = prepared }
            }
        }
    }
}
