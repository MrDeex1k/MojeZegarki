import SwiftUI
import SwiftData

struct WearTodayButton: View {
    let watch: Timepiece
    let store: CollectionStore
    var compact = false

    var body: some View {
        TimelineView(.periodic(from: Date(timeIntervalSince1970: 0), by: 60)) { timeline in
            let today = WearDay(timeline.date).key
            WearTodayDayButton(watch: watch, store: store, compact: compact, day: today)
                .id(today)
        }
    }
}

private struct WearTodayDayButton: View {
    let watch: Timepiece
    let store: CollectionStore
    let compact: Bool
    let day: String
    @Query private var logs: [WearLog]
    @State private var error: String?

    init(watch: Timepiece, store: CollectionStore, compact: Bool, day: String) {
        self.watch = watch
        self.store = store
        self.compact = compact
        self.day = day
        let watchID = watch.id
        _logs = Query(filter: #Predicate<WearLog> {
            $0.timepiece?.id == watchID && $0.calendarDay == day
        })
    }

    var body: some View {
        let logged = !logs.isEmpty
        Button {
            do { try store.logWear(for: watch, date: .now) }
            catch { self.error = error.localizedDescription }
        } label: {
            if compact {
                Image(systemName: logged ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.title2)
            } else {
                Label(logged ? "Worn today" : "Wearing today", systemImage: logged ? "checkmark.circle.fill" : "checkmark.circle")
            }
        }
        .buttonStyle(.borderless)
        .disabled(logged || watch.status != .owned)
        .accessibilityLabel(logged ? Text("Worn today") : Text("Wearing today"))
        .accessibilityHint(Text("\(watch.brand) \(watch.modelName)"))
        .accessibilityIdentifier(compact ? "wear.quick.\(watch.id)" : "wear.today")
        .appError($error)
    }
}

struct WearView: View {
    let store: CollectionStore
    var watch: Timepiece?
    @Query(sort: \WearLog.calendarDay, order: .reverse) private var logs: [WearLog]
    @Query(sort: \Timepiece.brand) private var watches: [Timepiece]
    @State private var adding = false
    @State private var editing: WearLog?
    @State private var deleting: WearLog?
    @State private var filterID: UUID?
    @State private var error: String?

    private var filtered: [WearLog] {
        logs.filter { log in
            guard let owner = log.timepiece else { return false }
            return (watch == nil || owner.id == watch?.id) && (filterID == nil || owner.id == filterID)
        }
    }

    private var groups: [(day: String, entries: [WearLog])] {
        Dictionary(grouping: filtered, by: \.calendarDay)
            .map { (day: $0.key, entries: $0.value) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        let days = groups
        List {
            if watch == nil && !watches.isEmpty {
                Section {
                    Picker("Watch", selection: $filterID) {
                        Text("All watches").tag(Optional<UUID>.none)
                        ForEach(watches) { Text("\($0.brand) \($0.modelName)").tag(Optional($0.id)) }
                    }
                }
            }
            if days.isEmpty {
                ContentUnavailableView("No wear history yet", systemImage: "calendar", description: Text("Log today or add a past day using the plus button."))
                    .listRowBackground(Color.clear)
            } else {
                Section { Text("\(days.count) days worn").font(.headline) }
                ForEach(days, id: \.day) { group in
                    Section {
                        ForEach(group.entries) { log in
                            if let owner = log.timepiece {
                                Button { editing = log } label: {
                                    HStack(spacing: 12) {
                                        PhotoView(photo: owner.mainPhoto.map { PhotoDraft(id: $0.id, filename: $0.filename) }, store: store.photoStore)
                                            .frame(width: 50, height: 58).clipShape(RoundedRectangle(cornerRadius: 8))
                                        VStack(alignment: .leading) {
                                            Text(owner.brand).font(.subheadline).foregroundStyle(.secondary)
                                            Text(owner.modelName).font(.headline).foregroundStyle(.primary)
                                            if owner.status != .owned { Text(owner.status.title).font(.caption).foregroundStyle(.secondary) }
                                        }
                                        Spacer()
                                        Image(systemName: "pencil").foregroundStyle(.secondary)
                                    }
                                }
                                .accessibilityIdentifier("wear.log.\(log.id)")
                                .swipeActions { Button("Delete", role: .destructive) { deleting = log } }
                                .contextMenu {
                                    Button("Edit") { editing = log }
                                    Button("Delete", role: .destructive) { deleting = log }
                                }
                            }
                        }
                    } header: {
                        if let date = WearDay(key: group.day)?.date() { Text(date.formatted(date: .complete, time: .omitted)) }
                    }
                }
            }
        }
        .navigationTitle("Wearing")
        .toolbar {
            Button("Add wear day", systemImage: "plus") { adding = true }
                .disabled(watches.isEmpty)
                .accessibilityIdentifier("wear.add")
        }
        .sheet(isPresented: $adding) { WearEditorView(store: store, initialWatch: watch) }
        .sheet(item: $editing) { WearEditorView(store: store, log: $0) }
        .confirmationDialog("Delete this wear entry?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                guard let deleting else { return }
                do { try store.deleteWear(deleting) } catch { self.error = error.localizedDescription }
                self.deleting = nil
            }
        }
        .appError($error)
    }
}

struct WearEditorView: View {
    let store: CollectionStore
    var log: WearLog?
    @Query(sort: \Timepiece.brand) private var watches: [Timepiece]
    @Environment(\.dismiss) private var dismiss
    @State private var watchID: UUID?
    @State private var date: Date
    @State private var error: String?

    init(store: CollectionStore, log: WearLog? = nil, initialWatch: Timepiece? = nil) {
        self.store = store
        self.log = log
        _watchID = State(initialValue: log?.timepiece?.id ?? initialWatch?.id)
        _date = State(initialValue: log.flatMap { WearDay(key: $0.calendarDay)?.date() } ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Watch", selection: $watchID) {
                    Text("Choose a watch").tag(Optional<UUID>.none)
                    ForEach(watches) { Text("\($0.brand) \($0.modelName)").tag(Optional($0.id)) }
                }
                .accessibilityIdentifier("wear.watch")
                DatePicker("Day", selection: $date, in: ...Date.now, displayedComponents: .date)
                Text("You can log several watches per day, once per watch. Archived watches can be logged for past days.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .navigationTitle(log == nil ? Text("Add wear day") : Text("Edit wear day"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let watch = watches.first(where: { $0.id == watchID }) else { return }
                        do { try store.logWear(for: watch, date: date, editing: log); dismiss() }
                        catch { self.error = error.localizedDescription }
                    }
                    .disabled(watchID == nil).accessibilityIdentifier("wear.save")
                }
            }
            .appError($error)
        }
    }
}
