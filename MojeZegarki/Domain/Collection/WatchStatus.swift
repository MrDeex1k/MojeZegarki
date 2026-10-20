import Foundation

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
