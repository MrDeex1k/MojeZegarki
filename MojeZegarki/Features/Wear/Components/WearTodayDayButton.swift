import SwiftData
import SwiftUI

struct WearTodayDayButton: View {
    let watch: Timepiece
    let store: CollectionStore
    let compact: Bool
    let day: String
    @Query private var logs: [WearLog]

    init(watch: Timepiece, store: CollectionStore, compact: Bool, day: String) {
        self.watch = watch
        self.store = store
        self.compact = compact
        self.day = day
        let watchID = watch.id
        _logs = Query(
            filter: #Predicate<WearLog> {
                $0.timepiece?.id == watchID && $0.calendarDay == day
            })
    }

    var body: some View {
        WearActionButton(watch: watch, store: store, compact: compact, logged: !logs.isEmpty)
    }
}
