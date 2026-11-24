import SwiftData
import SwiftUI

struct WearSummaryView: View {
    let dayKeys: Set<String>
    @Environment(\.locale) private var locale

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = locale
        value.firstWeekday = Calendar.current.firstWeekday
        return value
    }

    private var daysThisMonth: Int {
        guard let interval = calendar.dateInterval(of: .month, for: .now) else { return 0 }
        let start = WearDay(interval.start).key
        let end = WearDay(interval.end).key
        return dayKeys.filter { $0 >= start && $0 < end }.count
    }

    var body: some View {
        Section("Summary") {
            LabeledContent("Total") { Text("\(dayKeys.count) days worn").fontWeight(.semibold) }
            LabeledContent("This month") { Text("\(daysThisMonth) days worn") }
            LabeledContent("Last worn") {
                if let key = dayKeys.max(), let day = WearDay(key: key) {
                    Text(day.formatted(.abbreviated, locale: locale))
                } else {
                    Text("Not yet worn")
                }
            }
        }
    }
}
