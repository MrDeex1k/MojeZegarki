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

    private let rollbackManager = UndoManager()
    private let saveContext: @MainActor (ModelContext) throws -> Void

    /// Opens a store synchronously for tests and previews, with an optional failure injection point for saves.
    convenience init(
        directory: URL? = nil, inMemory: Bool = false,
        saveContext: @escaping @MainActor (ModelContext) throws -> Void = { try $0.save() }
    ) throws {
        try self.init(
            prepared: CollectionStorage.prepare(directory: directory, inMemory: inMemory), saveContext: saveContext)
    }

    private init(
        prepared: PreparedCollection,
        saveContext: @escaping @MainActor (ModelContext) throws -> Void = { try $0.save() }
    ) {
        root = prepared.root
        container = prepared.container
        self.saveContext = saveContext
        container.mainContext.autosaveEnabled = false
        photoStore = PhotoStore(
            root: root.appendingPathComponent("Photos", isDirectory: true),
            temporaryDirectory: prepared.temporaryDirectory)
        documentStore = DocumentStore(
            root: root.appendingPathComponent("Documents", isDirectory: true),
            temporaryDirectory: prepared.temporaryDirectory)
    }

    /// Prepares persistent storage off the main actor before creating the UI-facing store.
    static func open(directory: URL? = nil) async throws -> CollectionStore {
        let prepared = try await CollectionStorage().prepare(directory: directory)
        try Task.checkCancellation()
        return CollectionStore(prepared: prepared)
    }

    /// Rejects deleted, detached, and foreign models before an operation reads or mutates their relationships.
    func requireManaged(_ model: some PersistentModel) throws {
        guard model.modelContext === context, !model.isDeleted else { throw CollectionError.unavailableRecord }
    }

    /// Pair each mutation with persistChanges; there must be no suspension between them.
    func beginChanges() {
        rollbackManager.groupsByEvent = false
        rollbackManager.removeAllActions()
        context.undoManager = rollbackManager
        rollbackManager.beginUndoGrouping()
    }

    /// Saves a mutation or restores its values and affected relationships before propagating failure.
    func persistChanges(restoringRelationships: () -> Void = {}) throws {
        defer {
            if rollbackManager.groupingLevel > 0 { rollbackManager.endUndoGrouping() }
            rollbackManager.removeAllActions()
            context.undoManager = nil
        }
        var stage = "file protection"
        do {
            try StorageProtection.protectDatabaseFiles(in: root)
            stage = "database save"
            context.processPendingChanges()
            try saveContext(context)
            context.processPendingChanges()
        } catch {
            Logger(subsystem: "pl.jakubbatycki.MojeZegarki", category: "Storage").error(
                "Collection write failed during \(stage, privacy: .public): \(error, privacy: .private)")
            context.processPendingChanges()
            if rollbackManager.groupingLevel > 0 { rollbackManager.endUndoGrouping() }
            if rollbackManager.canUndo { rollbackManager.undo() }
            // On iOS 17 rollback alone leaves stale scalar values and deletion clears
            // relationship caches. Undo values and restore affected links before rollback.
            restoringRelationships()
            context.processPendingChanges()
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
