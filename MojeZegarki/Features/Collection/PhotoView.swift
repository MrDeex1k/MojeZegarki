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

struct WatchPhotoPreview: View {
    let photo: PhotoDraft
    let store: PhotoStore
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var loading = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .accessibilityLabel("Watch photo")
                        .accessibilityIdentifier("photoPreview.image")
                } else if loading {
                    ProgressView().tint(.white)
                } else {
                    ContentUnavailableView("Photo unavailable", systemImage: "photo.badge.exclamationmark")
                        .accessibilityIdentifier("photoPreview.unavailable")
                }
            }
            .navigationTitle("Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("photoPreview.close")
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .task(id: photo.id) {
            image = nil
            loading = true
            let prepared = await ImageLoader.load(photo, store: store, thumbnail: false)
            guard !Task.isCancelled else { return }
            image = prepared
            loading = false
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
