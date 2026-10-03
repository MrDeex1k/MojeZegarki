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
            if let photo {
                let prepared = await ImageLoader.load(photo, store: store, thumbnail: thumbnail)
                if !Task.isCancelled { image = prepared }
            }
        }
    }
}

/// Bounded decoded thumbnail cache. Full-size document and gallery images are not retained.
@MainActor enum ImageLoader {
    private static let thumbnails: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 24 * 1024 * 1024
        cache.countLimit = 32
        return cache
    }()

    static func prepare(_ data: Data) async -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        return await image.byPreparingForDisplay()
    }

    static func load(_ photo: PhotoDraft, store: PhotoStore, thumbnail: Bool) async -> UIImage? {
        let key = "\(store.root.path)/\(photo.id)/\(photo.filename)" as NSString
        if thumbnail, let cached = thumbnails.object(forKey: key) { return cached }
        guard let data = await store.data(for: photo, thumbnail: thumbnail), !Task.isCancelled,
            let image = await prepare(data), !Task.isCancelled
        else { return nil }
        if thumbnail {
            thumbnails.setObject(
                image, forKey: key, cost: Int(image.size.width * image.size.height * image.scale * image.scale * 4))
        }
        return image
    }
}
