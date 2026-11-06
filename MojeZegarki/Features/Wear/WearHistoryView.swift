import SwiftData
import SwiftUI

struct WearHistoryView: View {
    let store: CollectionStore
    var watch: Timepiece?
    @ScaledMetric(relativeTo: .body) private var headerHeight = 52
    @Query(sort: \WearLog.calendarDay, order: .reverse) private var logs: [WearLog]
    @Query(sort: \Timepiece.brand) private var watches: [Timepiece]
    @Bindable var session: WearHistorySession
    let presentsEditor: Bool
    @ScaledMetric(relativeTo: .title3) private var countFontSize = 20
    @State private var scrollBehavior = WearScrollBehavior()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.horizontalSizeClass) private var widthClass

    private var expanded: Bool { widthClass == .regular && !typeSize.isAccessibilitySize }

    /// Scopes the history query to the detail watch or the active watch filter when either exists.
    init(store: CollectionStore, watch: Timepiece?, session: WearHistorySession, presentsEditor: Bool) {
        self.store = store
        self.watch = watch
        self.session = session
        self.presentsEditor = presentsEditor
        if let id = watch?.id ?? session.filterID {
            _logs = Query(
                filter: WearLogScope.watch(id), sort: \WearLog.calendarDay, order: .reverse)
        }
    }

    private var filtered: [WearLog] {
        logs.filter { log in
            guard let owner = log.timepiece else { return false }
            return (watch == nil || owner.id == watch?.id) && (session.filterID == nil || owner.id == session.filterID)
        }
    }

    var body: some View {
        let days = Dictionary(grouping: filtered, by: \.calendarDay)
        ScrollViewReader { proxy in
            HStack(spacing: 0) {
                List {
                    if watch == nil && !watches.isEmpty {
                        Section {
                            WearWatchFilter(watches: watches, selection: $session.filterID)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }
                    }
                    if watch != nil {
                        WearSummaryView(dayKeys: Set(days.keys))
                    }
                    if days.isEmpty {
                        ContentUnavailableView {
                            Label("No wear history yet", systemImage: "calendar")
                        } description: {
                            Text("Add one or more days to your wear history.")
                        }
                        .listRowBackground(Color.clear)
                        Section {
                            addDaysButton
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }
                    } else {
                        if watch == nil {
                            Section {
                                statisticsButton(days: days.count)
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.clear)
                            }
                        }
                        Section {
                            addDaysButton
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }
                        Section {
                            WearCalendar(
                                counts: days.mapValues { Set($0.compactMap { $0.timepiece?.id }).count },
                                selectedDay: session.selectedDay,
                                singleWatch: watch != nil || session.filterID != nil,
                                displayedMonth: $session.month
                            ) {
                                session.selectedDay = $0
                                session.scrollRequest = UUID()
                            }
                        } header: {
                            Text("Wear calendar").foregroundStyle(Color(uiColor: .label))
                        } footer: {
                            if session.selectedDay == nil {
                                Text("Select a day to see worn watches").foregroundStyle(Color(uiColor: .label))
                                    .accessibilityIdentifier("wear.calendarHint")
                            }
                        }
                        if !expanded { selectedEntries(days: days) }
                    }
                }
                .listSectionSpacing(12)
                .scrollBounceBehavior(.basedOnSize)
                if expanded && !days.isEmpty {
                    Divider()
                    List {
                        if session.selectedDay == nil {
                            ContentUnavailableView("Select a day to see worn watches", systemImage: "calendar")
                        } else {
                            selectedEntries(days: days)
                        }
                    }
                }
            }
            .navigationTitle(watch == nil ? Text("Wearing") : Text("Wear overview"))
            .navigationBarTitleDisplayMode(watch == nil ? .large : .inline)
            .sheet(item: presentsEditor ? $session.editor : .constant(nil)) { editorSession in
                WearEditorView(store: store, session: editorSession) {
                    session.savedCount = $0
                }
            }
            .sheet(isPresented: $session.showingStatistics) {
                WearStatisticsView(initialWatchID: session.filterID)
            }
            .confirmationDialog(
                "Delete this wear entry?",
                isPresented: Binding(get: { session.deleting != nil }, set: { if !$0 { session.deleting = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    guard let deleting = session.deleting else { return }
                    do { try store.deleteWear(deleting) } catch { session.error = error.localizedDescription }
                    self.session.deleting = nil
                }
            }
            .task(id: session.scrollRequest) {
                guard !expanded, let selectedDay = session.selectedDay else { return }
                await Task.yield()
                let firstLog = days[selectedDay]?.first
                // A yield alone doesn't guarantee that List has inserted the new target.
                // Retry briefly; a newer selection or leaving the view cancels this request.
                for attempt in 0..<3 {
                    if attempt > 0 {
                        do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                    }
                    guard !Task.isCancelled, session.selectedDay == selectedDay else { return }
                    withAnimation(reduceMotion ? nil : .default) {
                        if let firstLog {
                            proxy.scrollTo("wear.result.\(firstLog.id)", anchor: .top)
                        } else {
                            proxy.scrollTo(Optional(selectedDay), anchor: .top)
                        }
                    }
                }
            }
            .onChange(of: session.filterID) { session.selectedDay = nil }
            .onChange(of: watches.map(\.id), initial: true) {
                if let id = session.filterID, !watches.contains(where: { $0.id == id }) {
                    session.filterID = nil
                }
            }
            .alert(
                "Wear history updated",
                isPresented: Binding(get: { session.savedCount != nil }, set: { if !$0 { session.savedCount = nil } })
            ) {
                Button("OK", role: .cancel) { session.savedCount = nil }
            } message: {
                Text("Added days: \(session.savedCount ?? 0)")
            }
            .appError($session.error)
        }
    }

    private func statisticsButton(days: Int) -> some View {
        Button {
            session.showingStatistics = true
        } label: {
            Text("\(days) days worn")
                .font(.system(size: countFontSize, weight: .semibold))
                .foregroundStyle(Color(uiColor: .label))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .frame(maxWidth: .infinity, minHeight: headerHeight)
                .overlay(alignment: .trailing) {
                    Image(systemName: "chevron.forward")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(uiColor: .label)).padding(.trailing, 16)
                }
                .background(
                    Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: typeSize.isAccessibilitySize ? 16 : 28))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("wear.statistics")
        .accessibilityHint("View wear statistics")
    }

    /// Shows only the chosen day and gives an empty selection a stable scroll target.
    @ViewBuilder private func selectedEntries(days: [String: [WearLog]]) -> some View {
        if let selectedDay = session.selectedDay {
            if let entries = days[selectedDay] {
                Section {
                    ForEach(entries) { log in
                        WearLogRow(
                            log: log, store: store, onEdit: { session.editor = WearEditorSession(log: log) },
                            onDelete: { session.deleting = log })
                    }
                } header: {
                    if let date = WearDay(key: selectedDay)?.date() {
                        Text(date.formatted(date: .complete, time: .omitted))
                            .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 3, trailing: 16))
                    }
                }
            } else {
                Text("No wear entries for this day")
                    .foregroundStyle(Color(uiColor: .label)).listRowBackground(Color.clear)
                    .id(Optional(selectedDay))
            }
        }
    }

    private var addDaysButton: some View {
        Button {
            session.editor = WearEditorSession(initialWatch: watch ?? watches.first { $0.id == session.filterID })
        } label: {
            Label("Add wear days", systemImage: "plus")
                .labelStyle(.titleAndIcon)
                .font(.headline)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: headerHeight)
                .foregroundStyle(Color.accentColor)
                .background(
                    Color.accentColor.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: typeSize.isAccessibilitySize ? 16 : 28))
        }
        .buttonStyle(.plain)
        .disabled(watches.isEmpty)
        .opacity(watches.isEmpty ? 0.5 : 1)
        .accessibilityIdentifier("wear.add")
        .background {
            if watch != nil {
                WearScrollAnchor(behavior: scrollBehavior).frame(width: 0, height: 0)
            }
        }
    }
}
