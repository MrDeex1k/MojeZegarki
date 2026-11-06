import Foundation
import OSLog
import SwiftData

extension CollectionStore {
    /// Takes a snapshot of referenced assets before removing unreferenced files.
    func reconcileAssets(
        cleanPhotos: ((Set<UUID>) async throws -> Void)? = nil,
        cleanDocuments: ((Set<UUID>) async throws -> Void)? = nil
    ) async throws {
        let signposter = OSSignposter(subsystem: "pl.jakubbatycki.MojeZegarki", category: "Storage")
        let interval = signposter.beginInterval("Reconcile collection assets")
        defer { signposter.endInterval("Reconcile collection assets", interval) }
        let inventory = AssetInventory(container: container)
        var failures: [any Error] = []
        do {
            let keeping = try await inventory.photoIDs()
            if let cleanPhotos {
                try await cleanPhotos(keeping)
            } else {
                try await photoStore.removeUnreferenced(keeping: keeping)
            }
        } catch { failures.append(error) }
        do {
            let ids = try await inventory.documentIDs()
            if let cleanDocuments {
                try await cleanDocuments(ids)
            } else {
                try await documentStore.removeUnreferenced(keeping: ids)
            }
        } catch { failures.append(error) }
        if !failures.isEmpty { throw AssetReconciliationError(failures: failures) }
    }

}
