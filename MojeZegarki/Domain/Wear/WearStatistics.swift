import Foundation

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
