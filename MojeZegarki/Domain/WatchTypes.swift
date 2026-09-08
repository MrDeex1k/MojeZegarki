import Foundation

protocol WatchOption: RawRepresentable, CaseIterable, Identifiable, Hashable where RawValue == String {
    var title: LocalizedStringResource { get }
}

extension WatchOption {
    var id: String { rawValue }
}

enum WatchStatus: String, WatchOption {
    case owned, sold, destroyed
    var title: LocalizedStringResource {
        switch self {
        case .owned: "Owned"
        case .sold: "Sold"
        case .destroyed: "Destroyed"
        }
    }
}

enum DeviceKind: String, WatchOption {
    case traditional, smartwatch
    var title: LocalizedStringResource {
        switch self {
        case .traditional: "Traditional watch"
        case .smartwatch: "Smartwatch"
        }
    }
}

enum MovementType: String, WatchOption {
    case manual, automatic, quartz, other, unknown
    var title: LocalizedStringResource {
        switch self {
        case .manual: "Manual winding"
        case .automatic: "Automatic"
        case .quartz: "Quartz"
        case .other: "Other"
        case .unknown: "Unknown"
        }
    }
}

enum WatchCategory: String, WatchOption {
    case diver, dress, sport, pilot, field, everyday
    var title: LocalizedStringResource {
        switch self {
        case .diver: "Diver"
        case .dress: "Dress"
        case .sport: "Sport"
        case .pilot: "Pilot"
        case .field: "Field"
        case .everyday: "Everyday"
        }
    }
}

enum CollectionError: LocalizedError {
    case requiredFields, invalidPrice, invalidCurrency, unreadablePhoto, saveFailed, fileAccess

    var errorDescription: String? {
        switch self {
        case .requiredFields: String(localized: "Enter a brand and model.")
        case .invalidPrice: String(localized: "Enter a non-negative price using your decimal separator, without thousands separators.")
        case .invalidCurrency: String(localized: "Choose a currency for the purchase price.")
        case .unreadablePhoto: String(localized: "This photo could not be read. Choose another image.")
        case .saveFailed: String(localized: "Changes could not be saved. Check available storage and try again.")
        case .fileAccess: String(localized: "Photo files could not be accessed. Try again.")
        }
    }
}

struct PhotoDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    let filename: String
}

struct TimepieceDraft {
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

    var hasRequiredFields: Bool { !brand.trimmed.isEmpty && !modelName.trimmed.isEmpty }

    func validatedPrice(locale: Locale = .current) throws -> String? {
        guard hasRequiredFields else { throw CollectionError.requiredFields }
        guard !price.trimmed.isEmpty else { return nil }
        let separator = locale.decimalSeparator ?? "."
        let canonical = price.trimmed.replacingOccurrences(of: separator, with: ".")
        // No permissive NumberFormatter parsing: partial numbers must never be silently accepted.
        guard canonical.range(of: "^[0-9]{1,18}(\\.[0-9]{1,6})?$", options: .regularExpression) != nil,
              let amount = Decimal(string: canonical, locale: Locale(identifier: "en_US_POSIX")) else {
            throw CollectionError.invalidPrice
        }
        guard Locale.commonISOCurrencyCodes.contains(currencyCode) else { throw CollectionError.invalidCurrency }
        return NSDecimalNumber(decimal: amount).stringValue
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { trimmed.isEmpty ? nil : trimmed }
}
