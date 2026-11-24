import SwiftData
import SwiftUI

struct WearMonthEntries<Content: View>: View {
    @Query private var logs: [WearLog]
    let content: ([String: [WearLog]]) -> Content

    init(
        month: Date, watchID: UUID?, selectedDay: String?,
        @ViewBuilder content: @escaping ([String: [WearLog]]) -> Content
    ) {
        let filter = WearLogScope.month(month, watchID: watchID, selectedDay: selectedDay)
        _logs = Query(filter: filter, sort: \WearLog.calendarDay, order: .reverse)
        self.content = content
    }

    var body: some View { content(Dictionary(grouping: logs, by: \.calendarDay)) }
}
