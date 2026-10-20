import SwiftData
import XCTest

@testable import MojeZegarki

@MainActor
final class WearLogScopeTests: XCTestCase {
    func testDatabaseScopesPreservePeriodStatisticsAndWatchIsolation() throws {
        let store = try CollectionStore(inMemory: true)
        var draft = TimepieceDraft()
        draft.brand = "Test"
        draft.modelName = "First"
        let a = try store.save(draft)
        draft.modelName = "Second"
        let b = try store.save(draft)
        for (watch, days) in [
            (a, ["2025-12-31", "2026-01-01", "2026-09-19", "2026-09-20", "2026-10-19", "2026-10-20"]),
            (b, ["2026-10-19"]),
        ] {
            for day in days { store.context.insert(WearLog(day: day, timepiece: watch)) }
        }
        try store.context.save()
        let now = try XCTUnwrap(WearDay(key: "2026-10-19")?.date())
        let all = try store.context.fetch(FetchDescriptor<WearLog>())
        func entries(_ logs: [WearLog]) -> [WearStatistics.Entry] {
            logs.compactMap { log in log.timepiece.map { .init(watchID: $0.id, day: log.calendarDay) } }
        }
        for period in WearStatistics.Period.allCases {
            let logs = try store.context.fetch(
                FetchDescriptor<WearLog>(predicate: WearLogScope.period(period, now: now)))
            let expected = WearStatistics(entries: entries(all), period: period, now: now)
            let actual = WearStatistics(entries: entries(logs), period: period, now: now)
            XCTAssertEqual(actual.daysByWatch, expected.daysByWatch)
            XCTAssertEqual(actual.calendarDays, expected.calendarDays)
            XCTAssertEqual(actual.recordedDays, expected.recordedDays)
        }
        let own = try store.context.fetch(FetchDescriptor<WearLog>(predicate: WearLogScope.watch(b.id)))
        XCTAssertEqual(own.count, 1)
        XCTAssertEqual(own.first?.timepiece?.id, b.id)
    }
}
