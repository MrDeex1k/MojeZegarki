import Foundation

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
