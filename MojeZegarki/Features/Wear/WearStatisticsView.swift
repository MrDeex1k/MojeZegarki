import SwiftUI

struct WearStatisticsView: View {
    let initialWatchID: UUID?
    @State private var period: WearStatistics.Period = .month

    var body: some View {
        TimelineView(.periodic(from: Date(timeIntervalSince1970: 0), by: 60)) { timeline in
            WearStatisticsContent(initialWatchID: initialWatchID, period: $period, now: timeline.date)
        }
    }
}
