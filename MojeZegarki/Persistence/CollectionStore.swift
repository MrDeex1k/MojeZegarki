import Foundation
import SwiftData

@MainActor
final class CollectionStore {
    let container: ModelContainer
    let photoStore: PhotoStore
    let documentStore: DocumentStore
    var context: ModelContext { container.mainContext }

    init(directory: URL? = nil, inMemory: Bool = false) throws {
        let root = try directory ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("MojeZegarki", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let schema = Schema(versionedSchema: CollectionSchemaV2.self)
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(schema: schema, url: root.appendingPathComponent("collection.store"), cloudKitDatabase: .none)
        }
        container = try ModelContainer(for: schema, migrationPlan: CollectionMigrationPlan.self, configurations: [configuration])
        container.mainContext.autosaveEnabled = false
        photoStore = PhotoStore(root: root.appendingPathComponent("Photos", isDirectory: true))
        documentStore = DocumentStore(root: root.appendingPathComponent("Documents", isDirectory: true))
    }

    /// Editors own drafts and staged files. Only a successful explicit save changes the collection.
    @discardableResult
    func save(_ draft: TimepieceDraft, editing existing: Timepiece? = nil, moving wishlistItem: WishlistItem? = nil, locale: Locale = .current) throws -> Timepiece {
        let price = try draft.validatedPrice(locale: locale)
        let watch = existing ?? Timepiece(brand: draft.brand.trimmed, modelName: draft.modelName.trimmed)
        if existing == nil { context.insert(watch) }
        watch.brand = draft.brand.trimmed
        watch.modelName = draft.modelName.trimmed
        watch.deviceKindRaw = draft.deviceKind?.rawValue
        watch.movementTypeRaw = draft.movementType?.rawValue
        watch.categoryIDs = draft.categories.map(\.rawValue).sorted()
        watch.referenceNumber = draft.referenceNumber.nilIfEmpty
        watch.serialNumber = draft.serialNumber.nilIfEmpty
        watch.purchaseDate = draft.purchaseDate
        watch.purchasePrice = price
        watch.currencyCode = price == nil ? nil : draft.currencyCode
        watch.seller = draft.seller.nilIfEmpty
        watch.notes = draft.notes.nilIfEmpty
        watch.statusRaw = draft.status.rawValue
        watch.updatedAt = Date()
        let oldPhotos = watch.photos ?? []
        for photo in oldPhotos where !draft.photos.contains(where: { $0.id == photo.id }) {
            context.delete(photo)
        }
        watch.photos = draft.photos.enumerated().map { index, item in
            let photo = oldPhotos.first { $0.id == item.id } ?? TimepiecePhoto(id: item.id, filename: item.filename, position: index)
            photo.position = index
            photo.timepiece = watch
            return photo
        }
        watch.mainPhotoID = draft.photos.contains { $0.id == draft.mainPhotoID } ? draft.mainPhotoID : draft.photos.first?.id
        // Moving is one transaction: validation or a failed save must preserve the wish.
        if let wishlistItem { context.delete(wishlistItem) }
        do { try context.save() } catch {
            context.rollback()
            throw CollectionError.saveFailed
        }
        return watch
    }

    func changeStatus(_ status: WatchStatus, for watch: Timepiece) throws {
        watch.statusRaw = status.rawValue
        watch.updatedAt = Date()
        do { try context.save() } catch {
            context.rollback()
            throw CollectionError.saveFailed
        }
    }

    func delete(_ watch: Timepiece) async throws {
        let photos = watch.sortedPhotos
        let photoIDs = photos.map(\.id)
        let documents = watch.documents ?? []
        let documentIDs = documents.map(\.id)
        // Explicit deletion also covers the iOS 17 SwiftData cascade behavior.
        for photo in photos { context.delete(photo) }
        for log in watch.wearLogs ?? [] { context.delete(log) }
        for document in documents { context.delete(document) }
        context.delete(watch)
        do { try context.save() } catch {
            context.rollback()
            throw CollectionError.saveFailed
        }
        // Failed filesystem cleanup is retried at next startup by reconcilePhotos().
        for id in photoIDs { try? await photoStore.remove(id) }
        for id in documentIDs { try? await documentStore.remove(id) }
    }

    func reconcilePhotos() async throws {
        let ids = try context.fetch(FetchDescriptor<TimepiecePhoto>()).map(\.id)
        let wishlistIDs = try context.fetch(FetchDescriptor<WishlistItem>()).compactMap(\.photoID)
        try await photoStore.removeUnreferenced(keeping: Set(ids + wishlistIDs))
        let documentIDs = try context.fetch(FetchDescriptor<DocumentItem>()).map(\.id)
        try await documentStore.removeUnreferenced(keeping: Set(documentIDs))
    }

    @discardableResult
    func logWear(for watch: Timepiece, date: Date, editing existing: WearLog? = nil, now: Date = .now, timeZone: TimeZone = .current) throws -> WearLog {
        guard watch.modelContext != nil, !watch.isDeleted else { throw WearError.missingWatch }
        let day = WearDay(date, timeZone: timeZone)
        let today = WearDay(now, timeZone: timeZone)
        guard day <= today else { throw WearError.futureDay }
        guard watch.status == .owned || day < today else { throw WearError.archivedToday }
        let watchID = watch.id
        let key = day.key
        let matches = try context.fetch(FetchDescriptor<WearLog>(predicate: #Predicate { $0.timepiece?.id == watchID && $0.calendarDay == key }))
        if let match = matches.first(where: { $0.id != existing?.id }) {
            if existing == nil { return match } // Repeated "Wearing today" is idempotent.
            throw WearError.duplicate
        }
        let log = existing ?? WearLog(day: key, timepiece: watch)
        if existing == nil { context.insert(log) }
        log.timepiece = watch
        log.calendarDay = key
        try persistChanges()
        return log
    }

    func deleteWear(_ log: WearLog) throws {
        context.delete(log)
        try persistChanges()
    }

    @discardableResult
    func saveWish(_ draft: WishlistDraft, editing existing: WishlistItem? = nil, locale: Locale = .current) throws -> WishlistItem {
        let price = try draft.purchaseDraft.validatedPrice(locale: locale)
        let url = try draft.validatedURL()
        let item = existing ?? WishlistItem(brand: draft.brand.trimmed, modelName: draft.modelName.trimmed)
        if existing == nil { context.insert(item) }
        item.brand = draft.brand.trimmed
        item.modelName = draft.modelName.trimmed
        item.targetPrice = price
        item.currencyCode = price == nil ? nil : draft.currencyCode
        item.url = url
        item.priority = draft.priority.rawValue
        item.notes = draft.notes.nilIfEmpty
        item.photoID = draft.photo?.id
        item.photoFilename = draft.photo?.filename
        item.updatedAt = .now
        try persistChanges()
        return item
    }

    func deleteWish(_ item: WishlistItem) async throws {
        let photoID = item.photoID
        context.delete(item)
        try persistChanges()
        if let photoID { try? await photoStore.remove(photoID) }
    }

    @discardableResult
    func attachDocument(_ asset: DocumentAsset, to watch: Timepiece, name: String, kind: DocumentKind, date: Date?, notes: String) throws -> DocumentItem {
        guard watch.modelContext != nil, !watch.isDeleted else { throw WearError.missingWatch }
        let watchID = watch.id
        let hash = asset.contentHash
        let matches = try context.fetch(FetchDescriptor<DocumentItem>(predicate: #Predicate { $0.timepiece?.id == watchID && $0.contentHash == hash }))
        guard matches.isEmpty else { throw DocumentError.duplicate }
        let document = DocumentItem(asset: asset, name: name.nilIfEmpty ?? String(localized: "Document"), timepiece: watch)
        context.insert(document)
        document.kindRaw = kind.rawValue
        document.documentDate = date
        document.notes = notes.nilIfEmpty
        try persistChanges()
        return document
    }

    func updateDocument(_ document: DocumentItem, name: String, kind: DocumentKind, date: Date?, notes: String) throws {
        document.displayName = name.nilIfEmpty ?? String(localized: "Document")
        document.kindRaw = kind.rawValue
        document.documentDate = date
        document.notes = notes.nilIfEmpty
        try persistChanges()
    }

    func deleteDocument(_ document: DocumentItem) async throws {
        let id = document.id
        context.delete(document)
        try persistChanges()
        try? await documentStore.remove(id)
    }

    private func persistChanges() throws {
        do { try context.save() } catch {
            context.rollback()
            throw CollectionError.saveFailed
        }
    }
}
