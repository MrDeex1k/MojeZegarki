import Foundation
import OSLog
import SwiftData

/// File metadata and migrations can be expensive; startup runs them on this actor.
actor CollectionStorage {
    /// Removes an isolated UI test directory before a reset launch opens its database.
    func resetTestDirectory(_ directory: URL) throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    /// Prepares a disk-backed collection on the storage actor before it is handed to the UI.
    func prepare(directory: URL?) throws -> PreparedCollection {
        try Self.prepare(directory: directory, inMemory: false)
    }

    /// Applies protection and backup metadata before opening the database and running migrations.
    nonisolated static func prepare(directory: URL?, inMemory: Bool) throws -> PreparedCollection {
        let temporaryDirectory = directory == nil && inMemory ? TemporaryCollectionDirectory() : nil
        let root: URL
        if let directory {
            root = directory
        } else if let temporaryDirectory {
            root = temporaryDirectory.url
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
            return PreparedCollection(root: root, container: container, temporaryDirectory: temporaryDirectory)
        } catch {
            Logger(subsystem: "pl.jakubbatycki.MojeZegarki", category: "Storage").error(
                "Collection database opening failed: \(error, privacy: .private)")
            throw error
        }
    }
}
