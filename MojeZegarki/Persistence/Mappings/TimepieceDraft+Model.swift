import Foundation

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
