import Foundation

enum DeviceKind: String, WatchOption {
    case traditional, smartwatch
    var title: LocalizedStringResource {
        switch self {
        case .traditional: "Traditional watch"
        case .smartwatch: "Smartwatch"
        }
    }
}
