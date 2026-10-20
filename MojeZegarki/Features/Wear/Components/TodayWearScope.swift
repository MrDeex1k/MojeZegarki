import SwiftData
import SwiftUI

/// One day-scoped query per collection, instead of one query and timer per row.
struct TodayWearScope<Content: View>: View {
    @Query private var logs: [WearLog]
    let content: (Set<UUID>) -> Content
    init(day: String, @ViewBuilder content: @escaping (Set<UUID>) -> Content) {
        _logs = Query(filter: #Predicate<WearLog> { $0.calendarDay == day })
        self.content = content
    }
    var body: some View { content(Set(logs.compactMap { $0.timepiece?.id })) }
}
