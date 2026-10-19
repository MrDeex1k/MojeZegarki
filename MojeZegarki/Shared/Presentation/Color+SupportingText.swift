import SwiftUI

extension Color {
    /// Opaque supporting text stays readable on grouped surfaces in either appearance.
    static let supportingText = Color(
        uiColor: UIColor { traits in
            UIColor(white: traits.userInterfaceStyle == .dark ? 0.75 : 0.35, alpha: 1)
        })
}
