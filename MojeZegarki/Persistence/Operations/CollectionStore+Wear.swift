import Foundation
import SwiftData

extension CollectionStore {
    /// Logs a day idempotently or edits an existing entry, restoring both owners if reassignment fails.
    @discardableResult
    func logWear(
        for watch: Timepiece, date: Date, editing existing: WearLog? = nil, now: Date = .now,
        timeZone: TimeZone = .current
    ) throws -> WearLog {
        try logWear(
            for: watch, on: WearDay(date, timeZone: timeZone), editing: existing,
            today: WearDay(now, timeZone: timeZone))
    }

    /// Saves a chosen calendar day without reinterpreting it in the device’s time zone.
    @discardableResult
    func logWear(
        for watch: Timepiece, on day: WearDay, editing existing: WearLog? = nil, today: WearDay = WearDay(.now)
    ) throws -> WearLog {
        try requireManaged(watch)
        if let existing { try requireManaged(existing) }
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
        let log = existing ?? WearLog(day: key, timepiece: nil)
        let previousWatch = existing?.timepiece
        let reassigning = existing != nil && previousWatch !== watch
        let previousLogs = reassigning ? previousWatch?.wearLogs : nil
        let destinationLogs = reassigning ? watch.wearLogs : nil
        beginChanges()
        if existing == nil { context.insert(log) }
        if previousWatch !== watch { log.timepiece = watch }
        log.calendarDay = key
        try persistChanges {
            guard reassigning else { return }
            // SwiftData can leave both inverse collections changed after a failed reassignment.
            watch.wearLogs = destinationLogs
            log.timepiece = previousWatch
            previousWatch?.wearLogs = previousLogs
        }
        return log
    }

    /// Validate the whole selection before inserting; save all new days together.
    @discardableResult
    func logWear(for watch: Timepiece, dates: [Date], now: Date = .now, timeZone: TimeZone = .current) throws -> Int {
        let days = Set(dates.map { WearDay($0, timeZone: timeZone) })
        return try logWear(for: watch, days: days, today: WearDay(now, timeZone: timeZone))
    }

    /// Validates and commits selected calendar keys without round-tripping through local dates.
    @discardableResult
    func logWear(for watch: Timepiece, days: Set<WearDay>, today: WearDay = WearDay(.now)) throws -> Int {
        try requireManaged(watch)
        guard days.allSatisfy({ $0 <= today }) else { throw WearError.futureDay }
        guard watch.status == .owned || days.allSatisfy({ $0 < today }) else { throw WearError.archivedToday }
        let watchID = watch.id
        guard let firstDay = days.min()?.key, let lastDay = days.max()?.key else { return 0 }
        var query = FetchDescriptor<WearLog>(
            predicate: #Predicate {
                $0.timepiece?.id == watchID && $0.calendarDay >= firstDay && $0.calendarDay <= lastDay
            })
        query.propertiesToFetch = [\.calendarDay]
        let existing = try context.fetch(query)
        let existingDays = Set(existing.map(\.calendarDay))
        let newDays = days.filter { !existingDays.contains($0.key) }.sorted()
        guard !newDays.isEmpty else { return 0 }
        beginChanges()
        for day in newDays {
            let log = WearLog(day: day.key, timepiece: nil)
            context.insert(log)
            log.timepiece = watch
        }
        try persistChanges()
        return newDays.count
    }

    /// Removes a wear entry while preserving the owner’s inverse relationship if the save fails.
    func deleteWear(_ log: WearLog) throws {
        try requireManaged(log)
        let watch = log.timepiece
        let logs = watch?.wearLogs
        beginChanges()
        context.delete(log)
        try persistChanges { watch?.wearLogs = logs }
    }

}
