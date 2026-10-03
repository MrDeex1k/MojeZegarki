import Foundation

/// A Gregorian calendar date, independent of the device's subsequent time zone changes.
struct WearDay: Hashable, Comparable, Sendable {
    let key: String

    init(_ date: Date, timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        key = String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    init?(key: String) {
        guard key.range(of: "^[0-9]{4}-[0-9]{2}-[0-9]{2}$", options: .regularExpression) != nil else { return nil }
        self.key = key
        guard let date = date(timeZone: TimeZone(secondsFromGMT: 0)!),
            WearDay(date, timeZone: TimeZone(secondsFromGMT: 0)!).key == key
        else { return nil }
    }

    func date(timeZone: TimeZone = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.key < rhs.key }
}

enum WearError: LocalizedError {
    case futureDay, archivedToday, duplicate, missingWatch
    var errorDescription: String? {
        switch self {
        case .futureDay: String(localized: "Wear history cannot be added for a future day.")
        case .archivedToday:
            String(localized: "Restore this watch before logging it for today. You can still add past days.")
        case .duplicate: String(localized: "This watch is already logged for that day.")
        case .missingWatch: String(localized: "The watch is no longer available.")
        }
    }
}

struct WearStatistics {
    enum Period: CaseIterable, Identifiable {
        case month, year, all
        var id: Self { self }
    }

    struct Entry {
        let watchID: UUID
        let day: String
    }

    let start: Date
    let calendarDays: Int
    let recordedDays: Int
    let daysByWatch: [UUID: Int]

    init(entries: [Entry], period: Period, now: Date = .now, timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let today = calendar.startOfDay(for: now)
        let todayKey = WearDay(now, timeZone: timeZone).key
        // Validate each distinct day once (many watches share the same date).
        let validKeys = Set(entries.map(\.day)).filter { $0 <= todayKey && WearDay(key: $0) != nil }
        switch period {
        case .month: start = calendar.date(byAdding: .day, value: -29, to: today)!
        case .year: start = calendar.date(from: calendar.dateComponents([.year], from: today))!
        case .all:
            start =
                validKeys.min().flatMap { WearDay(key: $0)?.date(timeZone: timeZone) }
                .map { calendar.startOfDay(for: $0) } ?? today
        }
        calendarDays = (calendar.dateComponents([.day], from: start, to: today).day ?? 0) + 1
        let startKey = WearDay(start, timeZone: timeZone).key
        let includedKeys = Set(validKeys.filter { $0 >= startKey })
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
