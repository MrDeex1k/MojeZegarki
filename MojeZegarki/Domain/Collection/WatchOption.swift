import Foundation

protocol WatchOption: RawRepresentable, CaseIterable, Identifiable, Hashable where RawValue == String {
    var title: LocalizedStringResource { get }
}

extension WatchOption {
    var id: String { rawValue }
}
