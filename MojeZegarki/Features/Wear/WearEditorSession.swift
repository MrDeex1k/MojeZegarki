import Foundation
import Observation

/// Owned by the presenting history, so a presentation resize cannot discard the draft.
@MainActor @Observable final class WearEditorSession: Identifiable {
    let id = UUID()
    let log: WearLog?
    var watchID: UUID?
    var date: Date
    var day: WearDay { WearDay(date, timeZone: .gmt) }
    var selectedDays: Set<String> = []
    var month = WearDay.calendar().dateInterval(of: .month, for: .now)!.start

    /// Anchors the draft to a calendar day before adapting it to the date picker’s Date binding.
    init(log: WearLog? = nil, initialWatch: Timepiece? = nil, now: Date = .now, timeZone: TimeZone = .current) {
        self.log = log
        watchID = log?.timepiece?.id ?? initialWatch?.id
        let day = log.flatMap { WearDay(key: $0.calendarDay) } ?? WearDay(now, timeZone: timeZone)
        // Use GMT only as the date picker's representation of the calendar day.
        date = WearDay.calendar(timeZone: .gmt).startOfDay(for: day.date(timeZone: .gmt)!)
    }
}
