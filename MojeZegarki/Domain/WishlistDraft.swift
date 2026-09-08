import Foundation

enum WishlistPriority: Int, CaseIterable, Identifiable {
    case unspecified = 0, low, medium, high
    var id: Int { rawValue }
    var title: LocalizedStringResource {
        switch self {
        case .unspecified: "Not specified"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }
}

struct WishlistDraft {
    var brand = ""
    var modelName = ""
    var price = ""
    var currencyCode = ""
    var url = ""
    var priority: WishlistPriority = .unspecified
    var notes = ""
    var photo: PhotoDraft?

    init() {}
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

    var purchaseDraft: TimepieceDraft {
        var draft = TimepieceDraft()
        draft.brand = brand
        draft.modelName = modelName
        draft.price = price
        draft.currencyCode = currencyCode
        draft.notes = notes
        draft.photos = photo.map { [$0] } ?? []
        draft.mainPhotoID = photo?.id
        return draft
    }

    func validatedURL() throws -> String? {
        guard let value = url.nilIfEmpty else { return nil }
        guard let parsed = URLComponents(string: value),
              ["https", "http"].contains(parsed.scheme?.lowercased() ?? ""),
              let host = parsed.host, !host.isEmpty, parsed.user == nil, parsed.password == nil else {
            throw WishlistError.invalidURL
        }
        return value
    }
}

enum WishlistError: LocalizedError {
    case invalidURL
    var errorDescription: String? { String(localized: "Enter a full http or https link without login details.") }
}
