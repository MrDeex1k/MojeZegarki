import Charts
import SwiftUI

struct WatchStatisticsRow: View {
    let watch: Timepiece
    let days: Int
    let maximum: Int
    let isSelected: Bool
    let onSelect: () -> Void
    var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(watch.brand).font(.caption).foregroundStyle(Color.supportingText)
                        Text(watch.modelName).font(.headline).foregroundStyle(
                            Color(uiColor: .label))
                    }
                    Spacer()
                    Text("\(days) days worn").font(.subheadline).monospacedDigit()
                        .foregroundStyle(Color.supportingText)
                }
                Chart {
                    BarMark(x: .value("Days", days), y: .value("Watch", ""))
                        .cornerRadius(4)
                        .foregroundStyle(
                            Color.accentColor.opacity(isSelected ? 1 : 0.4))
                }
                .chartXScale(domain: 0...maximum)
                .chartXAxis(.hidden).chartYAxis(.hidden)
                .frame(height: 12).accessibilityHidden(true)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Select watch for statistics")
    }
}
