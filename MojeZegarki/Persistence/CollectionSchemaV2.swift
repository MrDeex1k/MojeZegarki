import Foundation
import SwiftData

enum CollectionSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Timepiece.self, TimepiecePhoto.self, WearLog.self, WishlistItem.self, DocumentItem.self] }

    @Model
    final class Timepiece {
        var id: UUID = UUID()
        var brand: String = ""
        var modelName: String = ""
        var deviceKindRaw: String?
        var movementTypeRaw: String?
        var categoryIDs: [String] = []
        var referenceNumber: String?
        var serialNumber: String?
        var purchaseDate: Date?
        // Canonical decimal string avoids binary floating point and preserves optional zero.
        var purchasePrice: String?
        var currencyCode: String?
        var seller: String?
        var notes: String?
        var statusRaw: String = WatchStatus.owned.rawValue
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        var mainPhotoID: UUID?
        @Relationship(deleteRule: .cascade, inverse: \TimepiecePhoto.timepiece)
        var photos: [TimepiecePhoto]?
        @Relationship(deleteRule: .cascade, inverse: \WearLog.timepiece)
        var wearLogs: [WearLog]?
        @Relationship(deleteRule: .cascade, inverse: \DocumentItem.timepiece)
        var documents: [DocumentItem]?

        init(brand: String, modelName: String) {
            self.brand = brand
            self.modelName = modelName
        }

        var status: WatchStatus { WatchStatus(rawValue: statusRaw) ?? .owned }
        var sortedPhotos: [TimepiecePhoto] { (photos ?? []).sorted { $0.position < $1.position } }
        var mainPhoto: TimepiecePhoto? { sortedPhotos.first { $0.id == mainPhotoID } ?? sortedPhotos.first }
    }

    @Model
    final class TimepiecePhoto {
        var id: UUID = UUID()
        var filename: String = ""
        var position: Int = 0
        var createdAt: Date = Date()
        var timepiece: Timepiece?

        init(id: UUID, filename: String, position: Int) {
            self.id = id
            self.filename = filename
            self.position = position
        }
    }

    @Model
    final class WearLog {
        var id: UUID = UUID()
        var calendarDay: String = ""
        var createdAt: Date = Date()
        var timepiece: Timepiece?
        init(day: String, timepiece: Timepiece) {
            calendarDay = day
            self.timepiece = timepiece
        }
    }

    @Model
    final class WishlistItem {
        var id: UUID = UUID()
        var brand: String = ""
        var modelName: String = ""
        var targetPrice: String?
        var currencyCode: String?
        var url: String?
        var priority: Int = 0
        var notes: String?
        var photoID: UUID?
        var photoFilename: String?
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        init(brand: String, modelName: String) {
            self.brand = brand
            self.modelName = modelName
        }
        var photo: PhotoDraft? {
            guard let photoID, let photoFilename else { return nil }
            return PhotoDraft(id: photoID, filename: photoFilename)
        }
    }

    @Model
    final class DocumentItem {
        var id: UUID = UUID()
        var filename: String = ""
        var displayName: String = ""
        var contentType: String = ""
        var fileSize: Int = 0
        var contentHash: String = ""
        var kindRaw: String = "purchase"
        var documentDate: Date?
        var notes: String?
        var createdAt: Date = Date()
        var timepiece: Timepiece?
        init(asset: DocumentAsset, name: String, timepiece: Timepiece) {
            id = asset.id
            filename = asset.filename
            contentType = asset.contentType
            fileSize = asset.fileSize
            contentHash = asset.contentHash
            displayName = name
            self.timepiece = timepiece
        }
    }
}

typealias Timepiece = CollectionSchemaV2.Timepiece
typealias TimepiecePhoto = CollectionSchemaV2.TimepiecePhoto
typealias WearLog = CollectionSchemaV2.WearLog
typealias WishlistItem = CollectionSchemaV2.WishlistItem
typealias DocumentItem = CollectionSchemaV2.DocumentItem

enum CollectionMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [CollectionSchemaV1.self, CollectionSchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: CollectionSchemaV1.self, toVersion: CollectionSchemaV2.self)]
    }
}

extension TimepieceDraft {
    init(timepiece: Timepiece, locale: Locale = .current) {
        brand = timepiece.brand
        modelName = timepiece.modelName
        deviceKind = timepiece.deviceKindRaw.flatMap(DeviceKind.init(rawValue:))
        movementType = timepiece.movementTypeRaw.flatMap(MovementType.init(rawValue:))
        categories = Set(timepiece.categoryIDs.compactMap(WatchCategory.init(rawValue:)))
        referenceNumber = timepiece.referenceNumber ?? ""
        serialNumber = timepiece.serialNumber ?? ""
        purchaseDate = timepiece.purchaseDate
        price = (timepiece.purchasePrice ?? "").replacingOccurrences(of: ".", with: locale.decimalSeparator ?? ".")
        currencyCode = timepiece.currencyCode ?? ""
        seller = timepiece.seller ?? ""
        notes = timepiece.notes ?? ""
        status = timepiece.status
        photos = timepiece.sortedPhotos.map { PhotoDraft(id: $0.id, filename: $0.filename) }
        mainPhotoID = timepiece.mainPhotoID
    }
}
