import SwiftData
import SwiftUI

struct WearTodayButton: View {
    let watch: Timepiece
    let store: CollectionStore
    var compact = false
    var sharedLogged: Bool?

    var body: some View {
        if let sharedLogged {
            WearActionButton(watch: watch, store: store, compact: compact, logged: sharedLogged)
        } else {
            TimelineView(.periodic(from: Date(timeIntervalSince1970: 0), by: 60)) { timeline in
                let today = WearDay(timeline.date).key
                WearTodayDayButton(watch: watch, store: store, compact: compact, day: today)
                    .id(today)
            }
        }
    }
}
