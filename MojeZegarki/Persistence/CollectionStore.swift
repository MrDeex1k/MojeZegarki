import Foundation
import OSLog
import SwiftData

@MainActor
final class CollectionStore {
    private let root: URL
    let container: ModelContainer
    let photoStore: PhotoStore
    let documentStore: DocumentStore
    var context: ModelContext { container.mainContext }

    init(directory: URL? = nil, inMemory: Bool = false) throws {
        let root =
            try directory
            ?? FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
            )
            .appendingPathComponent("MojeZegarki", isDirectory: true)
        self.root = root
        try StorageProtection.prepareDirectory(root)
        try StorageProtection.protectExistingFiles(in: root)
        var backupRoot = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = false
        try backupRoot.setResourceValues(values)
        let schema = Schema(versionedSchema: CollectionSchemaV3.self)
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(
                schema: schema, url: root.appendingPathComponent("collection.store"), cloudKitDatabase: .none)
        }
        container = try ModelContainer(
            for: schema, migrationPlan: CollectionMigrationPlan.self, configurations: [configuration])
        container.mainContext.autosaveEnabled = false
        try StorageProtection.protectDatabaseFiles(in: root)
        photoStore = PhotoStore(root: root.appendingPathComponent("Photos", isDirectory: true))
        documentStore = DocumentStore(root: root.appendingPathComponent("Documents", isDirectory: true))
    }

    func persistChanges() throws {
        do {
            try StorageProtection.protectDatabaseFiles(in: root)
            try context.save()
        } catch {
            context.rollback()
            throw CollectionError.saveFailed
        }
        // A successful save is already durable. Never report it as rolled back or
        // let an editor discard its committed attachments if a metadata update fails.
        do { try StorageProtection.protectDatabaseFiles(in: root) } catch {
            Logger(subsystem: "pl.jakubbatycki.MojeZegarki", category: "Storage").error(
                "Database protection refresh failed: \(error.localizedDescription, privacy: .private)")
        }
    }
}
