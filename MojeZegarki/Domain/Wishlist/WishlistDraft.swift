import Foundation

struct WishlistDraft: Equatable {
    var brand = ""
    var modelName = ""
    var price = ""
    var currencyCode = ""
    var url = ""
    var priority: WishlistPriority = .unspecified
    var notes = ""
    var photo: PhotoDraft?

    init(locale: Locale = .current) {
        currencyCode = CurrencyPreference.defaultCode(for: locale)
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
            let host = parsed.host, !host.isEmpty, parsed.user == nil, parsed.password == nil
        else {
            throw WishlistError.invalidURL
        }
        return value
    }
}
