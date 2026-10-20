import SwiftData
import SwiftUI

struct WearSavedDays<Content: View>: View {
    @Query private var logs: [WearLog]
    let content: (Set<String>) -> Content
    init(watchID: UUID?, @ViewBuilder content: @escaping (Set<String>) -> Content) {
        _logs = Query(filter: #Predicate<WearLog> { $0.timepiece?.id == watchID })
        self.content = content
    }
    var body: some View { content(Set(logs.map(\.calendarDay))) }
}
