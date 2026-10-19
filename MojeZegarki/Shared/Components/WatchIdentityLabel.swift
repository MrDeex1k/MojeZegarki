import SwiftUI

struct WatchIdentityLabel: View {
    let brand: String
    let model: String
    var status: WatchStatus?
    var brandColor: Color = .supportingText
    var brandFont: Font = .subheadline
    var modelFont: Font = .headline
    var modelColor: Color = Color(uiColor: .label)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(brand).font(brandFont).foregroundStyle(brandColor)
            Text(model).font(modelFont).foregroundStyle(modelColor)
                .fixedSize(horizontal: false, vertical: true)
            if let status { Text(status.title).font(.caption).foregroundStyle(Color.supportingText) }
        }
    }
}
