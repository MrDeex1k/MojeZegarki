import Foundation

enum WishlistPriority: Int, CaseIterable, Identifiable {
    case unspecified = 0
    case low, medium, high
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
