import Foundation

struct TimepieceDraft: Equatable {
    var brand = ""
    var modelName = ""
    var deviceKind: DeviceKind?
    var movementType: MovementType?
    var categories: Set<WatchCategory> = []
    var referenceNumber = ""
    var serialNumber = ""
    var purchaseDate: Date?
    var price = ""
    var currencyCode = ""
    var seller = ""
    var notes = ""
    var status: WatchStatus = .owned
    var photos: [PhotoDraft] = []
    var mainPhotoID: UUID?

    init(locale: Locale = .current) {
        currencyCode = CurrencyPreference.defaultCode(for: locale)
    }

    var hasRequiredFields: Bool { !brand.trimmed.isEmpty && !modelName.trimmed.isEmpty }

    func validatedPrice(locale: Locale = .current) throws -> String? {
        guard hasRequiredFields else { throw CollectionError.requiredFields }
        guard !price.trimmed.isEmpty else { return nil }
        let separator = locale.decimalSeparator ?? "."
        let canonical = price.trimmed.replacingOccurrences(of: separator, with: ".")
        // No permissive NumberFormatter parsing: partial numbers must never be silently accepted.
        guard canonical.range(of: "^[0-9]{1,18}(\\.[0-9]{1,6})?$", options: .regularExpression) != nil,
            let amount = Decimal(string: canonical, locale: Locale(identifier: "en_US_POSIX"))
        else {
            throw CollectionError.invalidPrice
        }
        guard Locale.commonISOCurrencyCodes.contains(currencyCode) else { throw CollectionError.invalidCurrency }
        return NSDecimalNumber(decimal: amount).stringValue
    }
}
