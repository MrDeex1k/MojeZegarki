import Foundation

struct WearStatistics {
    enum Period: CaseIterable, Identifiable {
        case month, year, all
        var id: Self { self }

        /// Computes the inclusive lower bound from the same day key used by the database query.
        func startDay(endingOn today: WearDay) -> WearDay? {
            let calendar = WearDay.calendar(timeZone: .gmt)
            let date = today.date(timeZone: .gmt)!
            switch self {
            case .month:
                return WearDay(calendar.date(byAdding: .day, value: -29, to: date)!, timeZone: .gmt)
            case .year:
                return WearDay(calendar.dateInterval(of: .year, for: date)!.start, timeZone: .gmt)
            case .all:
                return nil
            }
        }
    }

    struct Entry {
        let watchID: UUID
        let day: String
    }

    let startDay: WearDay
    let endDay: WearDay
    let calendarDays: Int
    let recordedDays: Int
    let daysByWatch: [UUID: Int]

    /// Counts unique civil days and unique days per watch without relying on elapsed seconds.
    init(entries: [Entry], period: Period, now: Date = .now, timeZone: TimeZone = .current) {
        let today = WearDay(now, timeZone: timeZone)
        endDay = today
        let firstDay = period.startDay(endingOn: today)
        let cutoff = firstDay?.key
        // Validate each distinct day once (many watches share the same date).
        let includedKeys = Set(entries.map(\.day)).filter { key in
            key <= today.key && (cutoff.map { key >= $0 } ?? true) && WearDay(key: key) != nil
        }
        let start = firstDay ?? includedKeys.min().flatMap(WearDay.init(key:)) ?? today
        startDay = start
        // Compare civil dates in GMT so daylight-saving transitions and skipped local days
        // cannot shift the bounds or change the denominator.
        let calendar = WearDay.calendar(timeZone: .gmt)
        calendarDays =
            (calendar.dateComponents([.day], from: start.date(timeZone: .gmt)!, to: today.date(timeZone: .gmt)!).day
                ?? 0)
            + 1
        var watchDays: [UUID: Set<String>] = [:]
        for entry in entries where includedKeys.contains(entry.day) {
            watchDays[entry.watchID, default: []].insert(entry.day)
        }
        recordedDays = includedKeys.count
        daysByWatch = watchDays.mapValues(\.count)
    }

    func shareOfRecordedDays(for id: UUID) -> Double {
        guard recordedDays > 0 else { return 0 }
        return Double(daysByWatch[id, default: 0]) / Double(recordedDays)
    }
}
