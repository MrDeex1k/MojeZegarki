import SwiftData
import SwiftUI

struct WearEditorView: View {
    let store: CollectionStore
    var log: WearLog?
    @Query(sort: \Timepiece.brand) private var watches: [Timepiece]
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.dismiss) private var dismiss
    @State private var watchID: UUID?
    @State private var date: Date
    @State private var selectedDays: Set<String> = []
    var onSaved: (Int) -> Void = { _ in }
    @State private var error: String?

    init(
        store: CollectionStore, log: WearLog? = nil, initialWatch: Timepiece? = nil,
        onSaved: @escaping (Int) -> Void = { _ in }
    ) {
        self.onSaved = onSaved
        self.store = store
        self.log = log
        _watchID = State(initialValue: log?.timepiece?.id ?? initialWatch?.id)
        _date = State(initialValue: log.flatMap { WearDay(key: $0.calendarDay)?.date() } ?? .now)
    }

    var body: some View {
        WearSavedDays(watchID: watchID) { savedDays in
            let newDays = selectedDays.subtracting(savedDays)
            NavigationStack {
                Form {
                    Menu {
                        Picker("Watch", selection: $watchID) {
                            Text("Choose a watch").tag(Optional<UUID>.none)
                            ForEach(watches) { Text("\($0.brand) \($0.modelName)").tag(Optional($0.id)) }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Watch").font(.caption).foregroundStyle(.secondary)
                            if let selectedWatch {
                                Text("\(selectedWatch.brand) \(selectedWatch.modelName)")
                            } else {
                                Text("Choose a watch")
                            }
                        }.multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
                    }
                    .accessibilityIdentifier("wear.watch")
                    if log != nil {
                        DatePicker("Day", selection: $date, in: ...Date.now, displayedComponents: .date)
                    } else {
                        Section {
                            WearCalendar(
                                counts: Dictionary(uniqueKeysWithValues: savedDays.map { ($0, 1) }), pending: newDays,
                                editing: true, singleWatch: true, allowsToday: selectedWatch?.status == .owned,
                                enabled: selectedWatch != nil
                            ) { key in
                                if !selectedDays.insert(key).inserted { selectedDays.remove(key) }
                            }
                            Text("Selected days: \(newDays.count)")
                                .accessibilityIdentifier("wear.selectionCount")
                        } footer: {
                            Text("Days with a checkmark are already saved. Select new days marked with a plus.")
                        }
                    }
                    Text(
                        "You can log several watches per day, once per watch. Archived watches can be logged for past days."
                    )
                    .font(.footnote).foregroundStyle(.secondary)
                }
                .navigationTitle(log == nil ? Text("Wear days") : Text("Edit wear day"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            do {
                                guard let watch = watches.first(where: { $0.id == watchID }) else {
                                    throw WearError.missingWatch
                                }
                                if let log {
                                    try store.logWear(for: watch, date: date, editing: log)
                                } else {
                                    let dates = newDays.compactMap { WearDay(key: $0)?.date() }
                                    let count = try store.logWear(for: watch, dates: dates)
                                    onSaved(count)
                                }
                                dismiss()
                            } catch { self.error = error.localizedDescription }
                        } label: {
                            if log != nil {
                                Text("Save")
                            } else if typeSize.isAccessibilitySize {
                                Text("+\(newDays.count)")
                            } else {
                                Text("Add \(newDays.count) days")
                            }
                        }
                        .disabled(watchID == nil || (log == nil && newDays.isEmpty)).accessibilityIdentifier(
                            "wear.save")
                    }
                }
                .onChange(of: watchID) { selectedDays.removeAll() }
                .appError($error)
            }
        }

    }

    private var selectedWatch: Timepiece? { watches.first { $0.id == watchID } }
}

private struct WearSavedDays<Content: View>: View {
    @Query private var logs: [WearLog]
    let content: (Set<String>) -> Content
    init(watchID: UUID?, @ViewBuilder content: @escaping (Set<String>) -> Content) {
        _logs = Query(filter: #Predicate<WearLog> { $0.timepiece?.id == watchID })
        self.content = content
    }
    var body: some View { content(Set(logs.map(\.calendarDay))) }
}
