import Foundation

enum WishlistError: LocalizedError {
    case invalidURL, changedAfterMove, invalidOrder
    var errorDescription: String? {
        switch self {
        case .invalidOrder: String(localized: "The wishlist changed. Try reordering again.")
        case .invalidURL: String(localized: "Enter a full http or https link without login details.")
        case .changedAfterMove:
            String(localized: "This watch has changed since it was added. Undo is no longer available.")
        }
    }
}
