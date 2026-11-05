import Foundation
import Observation

/// Owned by the presenting history, so a presentation resize cannot discard the draft.
@MainActor @Observable final class WearEditorSession: Identifiable {
    let id = UUID()
    let log: WearLog?
    var watchID: UUID?
    var date: Date
    var selectedDays: Set<String> = []
    var month = WearDay.calendar().dateInterval(of: .month, for: .now)!.start

    init(log: WearLog? = nil, initialWatch: Timepiece? = nil, now: Date = .now, timeZone: TimeZone = .current) {
        self.log = log
        watchID = log?.timepiece?.id ?? initialWatch?.id
        let calendar = WearDay.calendar(timeZone: timeZone)
        date =
            log.flatMap { WearDay(key: $0.calendarDay)?.date(timeZone: timeZone) }
            .map { calendar.startOfDay(for: $0) } ?? now
    }
}
