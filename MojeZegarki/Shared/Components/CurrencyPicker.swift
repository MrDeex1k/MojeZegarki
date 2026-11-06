import SwiftUI

struct CurrencyPicker: View {
    @Binding var selection: String
    @Environment(\.dynamicTypeSize) private var typeSize

    private var value: Text { selection.isEmpty ? Text("Not specified") : Text(verbatim: selection) }

    var body: some View {
        NavigationLink {
            CurrencySelectionView(selection: $selection)
        } label: {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Currency").lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                    value.foregroundStyle(Color.supportingText)
                }
            } else {
                LabeledContent {
                    value.foregroundStyle(Color.supportingText).fixedSize(
                        horizontal: false, vertical: true)
                } label: {
                    Text("Currency").lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityIdentifier("currency.picker")
    }
}
