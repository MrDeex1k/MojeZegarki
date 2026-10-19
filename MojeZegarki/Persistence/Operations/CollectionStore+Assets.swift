import Foundation
import SwiftData

extension CollectionStore {
    func reconcileAssets(
        cleanPhotos: ((Set<UUID>) async throws -> Void)? = nil,
        cleanDocuments: ((Set<UUID>) async throws -> Void)? = nil
    ) async throws {
        var failures: [any Error] = []
        do {
            let ids = try context.fetch(FetchDescriptor<TimepiecePhoto>()).map(\.id)
            let wishlistIDs = try context.fetch(FetchDescriptor<WishlistItem>()).compactMap(\.photoID)
            let keeping = Set(ids + wishlistIDs)
            if let cleanPhotos {
                try await cleanPhotos(keeping)
            } else {
                try await photoStore.removeUnreferenced(keeping: keeping)
            }
        } catch { failures.append(error) }
        do {
            let ids = Set(try context.fetch(FetchDescriptor<DocumentItem>()).map(\.id))
            if let cleanDocuments {
                try await cleanDocuments(ids)
            } else {
                try await documentStore.removeUnreferenced(keeping: ids)
            }
        } catch { failures.append(error) }
        if !failures.isEmpty { throw AssetReconciliationError(failures: failures) }
    }

}
