import Foundation

enum WearError: LocalizedError {
    case futureDay, archivedToday, duplicate, missingWatch
    var errorDescription: String? {
        switch self {
        case .futureDay: String(localized: "Wear history cannot be added for a future day.")
        case .archivedToday:
            String(localized: "Restore this watch before logging it for today. You can still add past days.")
        case .duplicate: String(localized: "This watch is already logged for that day.")
        case .missingWatch: String(localized: "The watch is no longer available.")
        }
    }
}
