import Foundation

extension WishlistDraft {
    init(item: WishlistItem, locale: Locale = .current) {
        brand = item.brand
        modelName = item.modelName
        price = (item.targetPrice ?? "").replacingOccurrences(of: ".", with: locale.decimalSeparator ?? ".")
        currencyCode = item.currencyCode ?? ""
        url = item.url ?? ""
        priority = WishlistPriority(rawValue: item.priority) ?? .unspecified
        notes = item.notes ?? ""
        photo = item.photo
    }

}
