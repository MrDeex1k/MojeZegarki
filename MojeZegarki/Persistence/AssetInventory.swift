import Foundation
import SwiftData

/// Read committed references off the main actor before editors can stage new files.
actor AssetInventory {
    let container: ModelContainer
    init(container: ModelContainer) { self.container = container }

    /// Collects file identifiers from both watch and wishlist records before orphan cleanup.
    func photoIDs() throws -> Set<UUID> {
        let context = ModelContext(container)
        var photos = FetchDescriptor<TimepiecePhoto>()
        photos.propertiesToFetch = [\.id]
        var wishes = FetchDescriptor<WishlistItem>()
        wishes.propertiesToFetch = [\.photoID]
        return Set(try context.fetch(photos).map(\.id) + context.fetch(wishes).compactMap(\.photoID))
    }

    /// Collects document identifiers referenced by the database before orphan cleanup.
    func documentIDs() throws -> Set<UUID> {
        let context = ModelContext(container)
        var documents = FetchDescriptor<DocumentItem>()
        documents.propertiesToFetch = [\.id]
        return Set(try context.fetch(documents).map(\.id))
    }
}
