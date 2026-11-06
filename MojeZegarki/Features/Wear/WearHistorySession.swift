import Foundation
import Observation

/// Keeps nested presentations and calendar state alive when the history sheet is rebuilt.
@MainActor @Observable final class WearHistorySession: Identifiable {
    let id = UUID()
    var filterID: UUID?
    var editor: WearEditorSession?
    var month = WearDay.calendar().dateInterval(of: .month, for: .now)!.start
    var selectedDay: String?
    var deleting: WearLog?
    var showingStatistics = false
    var scrollRequest = UUID()
    var error: String?
    var savedCount: Int?
}
