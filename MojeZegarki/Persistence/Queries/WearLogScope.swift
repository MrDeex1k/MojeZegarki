import Foundation

/// Keep query boundaries aligned with the statistics calendar, including local midnight.
enum WearLogScope {
    static func watch(_ id: UUID) -> Predicate<WearLog> {
        #Predicate<WearLog> { $0.timepiece?.id == id }
    }

    static func period(_ period: WearStatistics.Period, now: Date, timeZone: TimeZone = .current) -> Predicate<WearLog>
    {
        let endDay = WearDay(now, timeZone: timeZone)
        let today = endDay.key
        if let cutoff = period.startDay(endingOn: endDay)?.key {
            return #Predicate<WearLog> { $0.calendarDay >= cutoff && $0.calendarDay <= today }
        }
        return #Predicate<WearLog> { $0.calendarDay <= today }
    }
}
