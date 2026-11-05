import Foundation
import OSLog
import SwiftData

/// File metadata and migrations can be expensive; startup runs them on this actor.
actor CollectionStorage {
    func resetTestDirectory(_ directory: URL) throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    func prepare(directory: URL?) throws -> PreparedCollection {
        try Self.prepare(directory: directory, inMemory: false)
    }

    nonisolated static func prepare(directory: URL?, inMemory: Bool) throws -> PreparedCollection {
        let root: URL
        if let directory {
            root = directory
        } else if inMemory {
            root = FileManager.default.temporaryDirectory.appendingPathComponent("CollectionPreview-\(UUID())")
        } else {
            root = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
            ).appendingPathComponent("MojeZegarki", isDirectory: true)
        }
        let signposter = OSSignposter(subsystem: "pl.jakubbatycki.MojeZegarki", category: "Storage")
        let preparation = signposter.beginInterval("Prepare collection files")
        do {
            try StorageProtection.prepareDirectory(root)
            try StorageProtection.protectExistingFiles(in: root)
            var backupRoot = root
            var values = URLResourceValues()
            values.isExcludedFromBackup = inMemory
            try backupRoot.setResourceValues(values)
        } catch {
            signposter.endInterval("Prepare collection files", preparation)
            Logger(subsystem: "pl.jakubbatycki.MojeZegarki", category: "Storage").error(
                "Collection file preparation failed: \(error, privacy: .private)")
            throw error
        }
        signposter.endInterval("Prepare collection files", preparation)
        let schema = Schema(versionedSchema: CollectionSchemaV3.self)
        let configuration =
            inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            : ModelConfiguration(
                schema: schema, url: root.appendingPathComponent("collection.store"), cloudKitDatabase: .none)
        let opening = signposter.beginInterval("Open collection database")
        defer { signposter.endInterval("Open collection database", opening) }
        do {
            let container = try ModelContainer(
                for: schema, migrationPlan: CollectionMigrationPlan.self, configurations: [configuration])
            try StorageProtection.protectDatabaseFiles(in: root)
            return PreparedCollection(root: root, container: container)
        } catch {
            Logger(subsystem: "pl.jakubbatycki.MojeZegarki", category: "Storage").error(
                "Collection database opening failed: \(error, privacy: .private)")
            throw error
        }
    }
}
