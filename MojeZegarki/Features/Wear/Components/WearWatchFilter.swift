import SwiftData
import SwiftUI

struct WearWatchFilter: View {
    let watches: [Timepiece]
    @Binding var selection: UUID?
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var headerHeight = 52
    var body: some View {
        Menu {
            Picker("Watch", selection: $selection) {
                Text("All watches").tag(Optional<UUID>.none)
                ForEach(watches, id: \.id) { Text("\($0.brand) \($0.modelName)").tag(Optional($0.id)) }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Watch").font(.caption).foregroundStyle(Color(uiColor: .label))
                    if let selected = watches.first(where: { $0.id == selection }) {
                        Text("\(selected.brand) \(selected.modelName)")
                    } else {
                        Text("All watches")
                    }
                }.multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image(systemName: "chevron.up.chevron.down").font(.caption)
            }.padding(.vertical, 10)
        }.accessibilityIdentifier("wear.filter")
            .padding(.horizontal, 16)
            .frame(minHeight: headerHeight)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: typeSize.isAccessibilitySize ? 16 : 28)
            )

    }
}
