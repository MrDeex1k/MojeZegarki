import Foundation
import SwiftData

extension CollectionStore {
    @discardableResult
    func logWear(
        for watch: Timepiece, date: Date, editing existing: WearLog? = nil, now: Date = .now,
        timeZone: TimeZone = .current
    ) throws -> WearLog {
        guard watch.modelContext != nil, !watch.isDeleted else { throw WearError.missingWatch }
        let day = WearDay(date, timeZone: timeZone)
        let today = WearDay(now, timeZone: timeZone)
        guard day <= today else { throw WearError.futureDay }
        guard watch.status == .owned || day < today else { throw WearError.archivedToday }
        let watchID = watch.id
        let key = day.key
        let matches = try context.fetch(
            FetchDescriptor<WearLog>(predicate: #Predicate { $0.timepiece?.id == watchID && $0.calendarDay == key }))
        if let match = matches.first(where: { $0.id != existing?.id }) {
            if existing == nil { return match }  // Repeated "Wearing today" is idempotent.
            throw WearError.duplicate
        }
        let log = existing ?? WearLog(day: key, timepiece: watch)
        if existing == nil { context.insert(log) }
        log.timepiece = watch
        log.calendarDay = key
        try persistChanges()
        return log
    }

    /// Validate the whole selection before inserting; save all new days together.
    @discardableResult
    func logWear(for watch: Timepiece, dates: [Date], now: Date = .now, timeZone: TimeZone = .current) throws -> Int {
        guard watch.modelContext != nil, !watch.isDeleted else { throw WearError.missingWatch }
        let days = Set(dates.map { WearDay($0, timeZone: timeZone) })
        let today = WearDay(now, timeZone: timeZone)
        guard days.allSatisfy({ $0 <= today }) else { throw WearError.futureDay }
        guard watch.status == .owned || days.allSatisfy({ $0 < today }) else { throw WearError.archivedToday }
        let watchID = watch.id
        let existing = try context.fetch(
            FetchDescriptor<WearLog>(predicate: #Predicate { $0.timepiece?.id == watchID }))
        let existingDays = Set(existing.map(\.calendarDay))
        let newDays = days.filter { !existingDays.contains($0.key) }.sorted()
        guard !newDays.isEmpty else { return 0 }
        for day in newDays { context.insert(WearLog(day: day.key, timepiece: watch)) }
        try persistChanges()
        return newDays.count
    }

    func deleteWear(_ log: WearLog) throws {
        context.delete(log)
        try persistChanges()
    }

}
