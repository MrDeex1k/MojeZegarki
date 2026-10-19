import Foundation

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
