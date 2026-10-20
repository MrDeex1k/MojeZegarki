import Foundation

enum CollectionError: LocalizedError {
    case requiredFields, invalidPrice, invalidCurrency, unreadablePhoto, saveFailed, fileAccess

    var errorDescription: String? {
        switch self {
        case .requiredFields: String(localized: "Enter a brand and model.")
        case .invalidPrice:
            String(localized: "Enter a non-negative price using your decimal separator, without thousands separators.")
        case .invalidCurrency: String(localized: "Choose a currency for the purchase price.")
        case .unreadablePhoto: String(localized: "This photo could not be read. Choose another image.")
        case .saveFailed: String(localized: "Changes could not be saved. Check available storage and try again.")
        case .fileAccess: String(localized: "Photo files could not be accessed. Try again.")
        }
    }
}
