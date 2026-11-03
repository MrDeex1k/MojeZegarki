import SwiftData
import SwiftUI

struct WearEditorView: View {
    let store: CollectionStore
    private var log: WearLog? { session.log }
    @Query(sort: \Timepiece.brand) private var watches: [Timepiece]
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: WearEditorSession
    var onSaved: (Int) -> Void = { _ in }
    @State private var error: String?

    init(store: CollectionStore, session: WearEditorSession, onSaved: @escaping (Int) -> Void = { _ in }) {
        self.store = store
        self.session = session
        self.onSaved = onSaved
    }

    var body: some View {
        WearSavedDays(watchID: session.watchID) { savedDays in
            let newDays = session.selectedDays.subtracting(savedDays)
            NavigationStack {
                Form {
                    Menu {
                        Picker("Watch", selection: $session.watchID) {
                            Text("Choose a watch").tag(Optional<UUID>.none)
                            ForEach(watches) { Text("\($0.brand) \($0.modelName)").tag(Optional($0.id)) }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Watch").font(.caption).foregroundStyle(Color.supportingText)
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
                        DatePicker("Day", selection: $session.date, in: ...Date.now, displayedComponents: .date)
                    } else {
                        Section {
                            WearCalendar(
                                counts: Dictionary(uniqueKeysWithValues: savedDays.map { ($0, 1) }), pending: newDays,
                                editing: true, singleWatch: true, allowsToday: selectedWatch?.status == .owned,
                                enabled: selectedWatch != nil, displayedMonth: $session.month
                            ) { key in
                                if !session.selectedDays.insert(key).inserted { session.selectedDays.remove(key) }
                            }
                            Text("Selected days: \(newDays.count)")
                                .accessibilityIdentifier("wear.selectionCount")
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .navigationTitle(log == nil ? Text("Wear days") : Text("Edit wear day"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            do {
                                guard let watch = watches.first(where: { $0.id == session.watchID }) else {
                                    throw WearError.missingWatch
                                }
                                if let log {
                                    try store.logWear(for: watch, date: session.date, editing: log)
                                } else {
                                    let dates = newDays.compactMap { WearDay(key: $0)?.date() }
                                    let count = try store.logWear(for: watch, dates: dates)
                                    onSaved(count)
                                }
                                dismiss()
                            } catch { self.error = error.localizedDescription }
                        } label: {
                            if log != nil {
                                Label("Save", systemImage: "checkmark")
                            } else if typeSize.isAccessibilitySize {
                                Label("+\(newDays.count)", systemImage: "plus")
                            } else {
                                Label("Add \(newDays.count) days", systemImage: "plus")
                            }
                        }
                        .accessibilityLabel(
                            log != nil ? Text("Save") : Text("Add wear days")
                        )
                        .accessibilityValue(log == nil ? Text("Selected days: \(newDays.count)") : Text(""))
                        .disabled(session.watchID == nil || (log == nil && newDays.isEmpty)).accessibilityIdentifier(
                            "wear.save")
                    }
                }
                .onChange(of: session.watchID) { session.selectedDays.removeAll() }
                .appError($error)
            }
        }

    }

    private var selectedWatch: Timepiece? { watches.first { $0.id == session.watchID } }
}
