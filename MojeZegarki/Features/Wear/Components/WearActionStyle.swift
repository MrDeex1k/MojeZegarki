import SwiftData
import SwiftUI

struct WearActionStyle: ViewModifier {
    let compact: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var typeSize

    @ViewBuilder
    func body(content: Content) -> some View {
        if compact {
            content.buttonStyle(.borderless)
        } else if #available(iOS 26.0, *), !reduceTransparency, contrast != .increased {
            content.buttonStyle(.glassProminent).buttonBorderShape(borderShape)
        } else {
            content.buttonStyle(.borderedProminent).buttonBorderShape(borderShape)
        }
    }

    private var borderShape: ButtonBorderShape {
        typeSize.isAccessibilitySize ? .roundedRectangle(radius: 16) : .capsule
    }
}
