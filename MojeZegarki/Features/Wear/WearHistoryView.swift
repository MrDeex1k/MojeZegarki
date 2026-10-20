import SwiftData
import SwiftUI

struct WearHistoryView: View {
    let store: CollectionStore
    var watch: Timepiece?
    @ScaledMetric(relativeTo: .body) private var headerHeight = 52
    @Query(sort: \WearLog.calendarDay, order: .reverse) private var logs: [WearLog]
    @Query(sort: \Timepiece.brand) private var watches: [Timepiece]
    @State private var adding = false
    @State private var editing: WearLog?
    @State private var deleting: WearLog?
    @State private var showingStatistics = false
    @State private var selectedDay: String?
    @State private var scrollRequest = UUID()
    @ScaledMetric(relativeTo: .title3) private var countFontSize = 20
    @Binding var filterID: UUID?
    @State private var error: String?
    @State private var savedCount: Int?
    @State private var scrollBehavior = WearScrollBehavior()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    init(store: CollectionStore, watch: Timepiece?, filterID: Binding<UUID?>) {
        self.store = store
        self.watch = watch
        _filterID = filterID
        if let id = watch?.id ?? filterID.wrappedValue {
            _logs = Query(
                filter: WearLogScope.watch(id), sort: \WearLog.calendarDay, order: .reverse)
        }
    }

    private var filtered: [WearLog] {
        logs.filter { log in
            guard let owner = log.timepiece else { return false }
            return (watch == nil || owner.id == watch?.id) && (filterID == nil || owner.id == filterID)
        }
    }

    var body: some View {
        let filteredLogs = filtered
        let days = Dictionary(grouping: filteredLogs, by: \.calendarDay).map { (day: $0.key, entries: $0.value) }
        ScrollViewReader { proxy in
            List {
                if watch == nil && !watches.isEmpty {
                    Section {
                        WearWatchFilter(watches: watches, selection: $filterID)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }
                if watch != nil {
                    WearSummaryView(dayKeys: Set(days.map(\.day)))
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
                            Button {
                                showingStatistics = true
                            } label: {
                                Text("\(days.count) days worn")
                                    .font(.system(size: countFontSize, weight: .semibold))
                                    .foregroundStyle(Color(uiColor: .label))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 36)
                                    .frame(maxWidth: .infinity, minHeight: headerHeight)
                                    .overlay(alignment: .trailing) {
                                        Image(systemName: "chevron.right")
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
                            counts: Dictionary(
                                uniqueKeysWithValues: days.map {
                                    ($0.day, Set($0.entries.compactMap { $0.timepiece?.id }).count)
                                }), selectedDay: selectedDay, singleWatch: watch != nil || filterID != nil
                        ) {
                            selectedDay = $0
                            scrollRequest = UUID()
                        }
                    } header: {
                        Text("Wear calendar").foregroundStyle(Color(uiColor: .label))
                    } footer: {
                        if selectedDay == nil {
                            Text("Select a day to see worn watches").foregroundStyle(Color(uiColor: .label))
                                .accessibilityIdentifier("wear.calendarHint")
                        }
                    }
                    if selectedDay != nil, !days.contains(where: { $0.day == selectedDay }) {
                        Text("No wear entries for this day")
                            .foregroundStyle(Color(uiColor: .label)).listRowBackground(Color.clear)
                            .id(selectedDay)
                    }
                    ForEach(days.filter { $0.day == selectedDay }, id: \.day) { group in
                        Section {
                            ForEach(group.entries) { log in
                                WearLogRow(
                                    log: log, store: store, onEdit: { editing = log }, onDelete: { deleting = log })
                            }
                        } header: {
                            if let date = WearDay(key: group.day)?.date() {
                                Text(date.formatted(date: .complete, time: .omitted))
                                    .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 3, trailing: 16))
                            }
                        }
                    }
                }
            }
            .listSectionSpacing(12)
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle(watch == nil ? Text("Wearing") : Text("Wear overview"))
            .navigationBarTitleDisplayMode(watch == nil ? .large : .inline)
            .sheet(isPresented: $adding) {
                WearEditorView(store: store, initialWatch: watch ?? watches.first { $0.id == filterID }) {
                    savedCount = $0
                }
            }
            .sheet(isPresented: $showingStatistics) {
                WearStatisticsView(initialWatchID: filterID)
            }
            .sheet(item: $editing) { WearEditorView(store: store, log: $0) }
            .confirmationDialog(
                "Delete this wear entry?",
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    guard let deleting else { return }
                    do { try store.deleteWear(deleting) } catch { self.error = error.localizedDescription }
                    self.deleting = nil
                }
            }
            .task(id: scrollRequest) {
                guard let selectedDay else { return }
                await Task.yield()
                let firstLog = filteredLogs.first { $0.calendarDay == selectedDay }
                // A yield alone doesn't guarantee that List has inserted the new target.
                // Retry briefly; a newer selection or leaving the view cancels this request.
                for attempt in 0..<3 {
                    if attempt > 0 {
                        do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                    }
                    guard !Task.isCancelled, self.selectedDay == selectedDay else { return }
                    withAnimation(reduceMotion ? nil : .default) {
                        if let firstLog {
                            proxy.scrollTo("wear.result.\(firstLog.id)", anchor: .top)
                        } else {
                            proxy.scrollTo(Optional(selectedDay), anchor: .top)
                        }
                    }
                }
            }
            .onChange(of: filterID) { selectedDay = nil }
            .alert(
                "Wear history updated",
                isPresented: Binding(get: { savedCount != nil }, set: { if !$0 { savedCount = nil } })
            ) {
                Button("OK", role: .cancel) { savedCount = nil }
            } message: {
                Text("Added days: \(savedCount ?? 0)")
            }
            .appError($error)
        }
    }

    private var addDaysButton: some View {
        Button {
            adding = true
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
