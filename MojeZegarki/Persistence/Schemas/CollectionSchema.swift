import Foundation
import SwiftData

enum CollectionSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Timepiece.self, TimepiecePhoto.self] }

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
}
