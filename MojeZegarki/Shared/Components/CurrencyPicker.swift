import SwiftUI

struct CurrencyPicker: View {
    @Binding var selection: String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        NavigationLink {
            CurrencySelectionView(selection: $selection)
        } label: {
            let value = selection.isEmpty ? String(localized: "Not specified") : selection
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Currency").lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: value).foregroundStyle(Color.supportingText)
                }
            } else {
                LabeledContent {
                    Text(verbatim: value).foregroundStyle(Color.supportingText).fixedSize(
                        horizontal: false, vertical: true)
                } label: {
                    Text("Currency").lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityIdentifier("currency.picker")
    }
}
