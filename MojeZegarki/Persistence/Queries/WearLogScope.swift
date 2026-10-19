import Foundation

/// Keep query boundaries aligned with the statistics calendar, including local midnight.
enum WearLogScope {
    static func watch(_ id: UUID) -> Predicate<WearLog> {
        #Predicate<WearLog> { $0.timepiece?.id == id }
    }

    static func period(_ period: WearStatistics.Period, now: Date) -> Predicate<WearLog>? {
        guard period != .all else { return nil }
        let cutoff = WearDay(WearStatistics(entries: [], period: period, now: now).start).key
        let today = WearDay(now).key
        return #Predicate<WearLog> { $0.calendarDay >= cutoff && $0.calendarDay <= today }
    }
}
