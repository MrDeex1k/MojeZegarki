import Foundation
import Observation

/// Owned by the presenting history, so a presentation resize cannot discard the draft.
@MainActor @Observable final class WearEditorSession: Identifiable {
    let id = UUID()
    let log: WearLog?
    var watchID: UUID?
    var date: Date
    var selectedDays: Set<String> = []
    var month = Calendar(identifier: .gregorian).dateInterval(of: .month, for: .now)!.start

    init(log: WearLog? = nil, initialWatch: Timepiece? = nil) {
        self.log = log
        watchID = log?.timepiece?.id ?? initialWatch?.id
        date = log.flatMap { WearDay(key: $0.calendarDay)?.date() } ?? .now
    }
}
