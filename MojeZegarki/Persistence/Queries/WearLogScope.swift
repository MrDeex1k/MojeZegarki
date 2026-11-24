import Foundation

/// Keep query boundaries aligned with the statistics calendar, including local midnight.
enum WearLogScope {
    static func watch(_ id: UUID) -> Predicate<WearLog> {
        #Predicate<WearLog> { $0.timepiece?.id == id }
    }

    /// Includes the selected day when it remains open while browsing another month.
    static func month(_ month: Date, watchID: UUID?, selectedDay: String?) -> Predicate<WearLog> {
        let interval = WearDay.calendar().dateInterval(of: .month, for: month)!
        let start = WearDay(interval.start).key
        let end = WearDay(interval.end).key
        let selected = selectedDay ?? ""
        if let watchID {
            return #Predicate {
                $0.timepiece?.id == watchID
                    && (($0.calendarDay >= start && $0.calendarDay < end) || $0.calendarDay == selected)
            }
        } else {
            return #Predicate {
                $0.timepiece != nil && (($0.calendarDay >= start && $0.calendarDay < end) || $0.calendarDay == selected)
            }
        }
    }

    /// Fetches only days in the inclusive statistics range, with no lower bound for all time.
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
