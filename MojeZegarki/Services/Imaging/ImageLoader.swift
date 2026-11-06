import UIKit

/// Bounded decoded thumbnail cache. Full-size document and gallery images are not retained.
@MainActor enum ImageLoader {
    static let access = ImageAccessState()
    private static let thumbnails: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 24 * 1024 * 1024
        cache.countLimit = 32
        return cache
    }()
    // Only active requests are tracked; invalidation must also reject their late results.
    private static var requests: [UUID: String] = [:]
    private static var invalidated: Set<UUID> = []

    /// Drops thumbnail cache entries and rejects results from reads that were already in flight.
    static func clearCache() {
        thumbnails.removeAllObjects()
        invalidated.formUnion(requests.keys)
    }

    /// Drops both filename variants for one photo without invalidating unrelated requests.
    static func invalidate(_ id: UUID, root: URL) {
        for filename in ["photo.heic", "photo.jpg"] {
            let key = "\(root.path)/\(id)/\(filename)"
            thumbnails.removeObject(forKey: key as NSString)
            invalidated.formUnion(requests.compactMap { $0.value == key ? $0.key : nil })
        }
    }

    static func prepare(_ data: Data) async -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        return await image.byPreparingForDisplay()
    }

    /// Reads or reuses an image and checks cancellation and invalidation before returning a result.
    static func load(
        _ photo: PhotoDraft, store: PhotoStore, thumbnail: Bool,
        prepareImage: @MainActor (Data) async -> UIImage? = ImageLoader.prepare
    ) async -> UIImage? {
        guard !Task.isCancelled else { return nil }
        let key = "\(store.root.path)/\(photo.id)/\(photo.filename)"
        if thumbnail, let cached = thumbnails.object(forKey: key as NSString) { return cached }
        let request = UUID()
        requests[request] = key
        defer {
            requests.removeValue(forKey: request)
            invalidated.remove(request)
        }
        guard let data = await store.data(for: photo, thumbnail: thumbnail), !Task.isCancelled,
            !invalidated.contains(request),
            let image = await prepareImage(data), !Task.isCancelled, !invalidated.contains(request)
        else { return nil }
        if thumbnail {
            let cost =
                image.cgImage.map { $0.bytesPerRow * $0.height }
                ?? Int(image.size.width * image.size.height * image.scale * image.scale * 4)
            thumbnails.setObject(
                image, forKey: key as NSString, cost: cost)
        }
        return image
    }
}
