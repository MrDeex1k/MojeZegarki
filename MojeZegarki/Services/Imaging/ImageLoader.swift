import UIKit

/// Bounded decoded thumbnail cache. Full-size document and gallery images are not retained.
@MainActor enum ImageLoader {
    private static let thumbnails: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 24 * 1024 * 1024
        cache.countLimit = 32
        return cache
    }()

    static func clearCache() { thumbnails.removeAllObjects() }

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
