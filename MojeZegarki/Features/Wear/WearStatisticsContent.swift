import SwiftData
import SwiftUI

struct WearStatisticsContent: View {
    let initialWatchID: UUID?
    let now: Date
    @Query private var logs: [WearLog]
    @Query(sort: \Timepiece.brand) private var watches: [Timepiece]
    @Binding var period: WearStatistics.Period

    init(
        initialWatchID: UUID?, period: Binding<WearStatistics.Period>, currentPeriod: WearStatistics.Period, now: Date
    ) {
        self.initialWatchID = initialWatchID
        self.now = now
        _period = period
        _logs = Query(filter: WearLogScope.period(currentPeriod, now: now))
    }

    private var statistics: WearStatistics {
        WearStatistics(
            entries: logs.compactMap { log in
                log.timepiece.map { WearStatistics.Entry(watchID: $0.id, day: log.calendarDay) }
            }, period: period, now: now)
    }

    private func ranked(using stats: WearStatistics) -> [Timepiece] {
        watches.sorted {
            let left = stats.daysByWatch[$0.id, default: 0]
            let right = stats.daysByWatch[$1.id, default: 0]
            if left != right { return left > right }
            return "\($0.brand) \($0.modelName) \($0.id)" < "\($1.brand) \($1.modelName) \($1.id)"
        }
    }

    var body: some View {
        let stats = statistics
        StatisticsPresentation(
            initialWatchID: initialWatchID, watches: watches, ranking: ranked(using: stats),
            stats: stats, maximum: max(stats.daysByWatch.values.max() ?? 0, 1), period: $period)
    }
}
