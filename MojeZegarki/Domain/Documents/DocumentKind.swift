import Foundation

enum DocumentKind: String, WatchOption {
    case purchase, warranty, service, other
    var title: LocalizedStringResource {
        switch self {
        case .purchase: "Purchase"
        case .warranty: "Warranty"
        case .service: "Service"
        case .other: "Other"
        }
    }
}
