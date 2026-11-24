import Foundation

struct WearDay: Hashable, Comparable, Sendable {
    let key: String

    /// Captures the Gregorian calendar day for this instant in the supplied time zone.
    init(_ date: Date, timeZone: TimeZone = .current) {
        let calendar = Self.calendar(timeZone: timeZone)
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

    /// Returns a date suitable for presentation in the requested calendar context.
    func date(timeZone: TimeZone = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Self.calendar(timeZone: timeZone).date(
            from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    /// Format a stored civil day independently of transitions in the device’s time zone.
    func formatted(_ style: Date.FormatStyle.DateStyle, locale: Locale) -> String {
        date(timeZone: .gmt)!.formatted(
            Date.FormatStyle(
                date: style, time: .omitted, locale: locale, calendar: Self.calendar(timeZone: .gmt), timeZone: .gmt))
    }

    /// Uses the Gregorian calendar for stored day keys regardless of the device calendar.
    static func calendar(timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.key < rhs.key }
}
