import SwiftUI
import SwiftData
import Charts

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                    .labelStyle(.titleOnly)
                    .font(.headline)
                    .foregroundStyle(logged ? Color.primary : Color(uiColor: .systemBackground))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 28)
                    .padding(.vertical, 4)
                    .contentTransition(.opacity)
            }
        }
        .modifier(WearActionStyle(compact: compact))
        .disabled(logged || watch.status != .owned)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: logged)
        .accessibilityLabel(logged ? Text("Worn today") : Text("Wearing today"))
        .accessibilityHint(Text("\(watch.brand) \(watch.modelName)"))
        .accessibilityIdentifier(compact ? "wear.quick.\(watch.id)" : "wear.today")
        .appError($error)
    }
}

private struct WearActionStyle: ViewModifier {
    let compact: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var typeSize

    @ViewBuilder
    func body(content: Content) -> some View {
        if compact {
            content.buttonStyle(.borderless)
        } else if #available(iOS 26.0, *), !reduceTransparency, contrast != .increased {
            content.buttonStyle(.glassProminent).buttonBorderShape(borderShape)
        } else {
            content.buttonStyle(.borderedProminent).buttonBorderShape(borderShape)
        }
    }

    private var borderShape: ButtonBorderShape {
        typeSize.isAccessibilitySize ? .roundedRectangle(radius: 16) : .capsule
    }
}

struct WearView: View {
    let store: CollectionStore
    var watch: Timepiece?
    @ScaledMetric(relativeTo: .subheadline) private var brandFontSize = 18.75
    @ScaledMetric(relativeTo: .headline) private var modelFontSize = 20
    @ScaledMetric(relativeTo: .body) private var headerHeight = 52
    @Query(sort: \WearLog.calendarDay, order: .reverse) private var logs: [WearLog]
    @Query(sort: \Timepiece.brand) private var watches: [Timepiece]
    @State private var adding = false
    @State private var editing: WearLog?
    @State private var deleting: WearLog?
    @State private var showingStatistics = false
    @ScaledMetric(relativeTo: .title3) private var countFontSize = 20
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
                    .padding(.horizontal, 16)
                    .frame(minHeight: headerHeight)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            if watch != nil {
                WearSummaryView(dayKeys: Set(filtered.map(\.calendarDay)))
            }
            if days.isEmpty {
                ContentUnavailableView {
                    Label("No wear history yet", systemImage: "calendar")
                } description: {
                    Text("Add one or more days to your wear history.")
                } actions: {
                    addDaysButton
                }
                .listRowBackground(Color.clear)
            } else {
                if watch == nil {
                    Section {
                        Button { showingStatistics = true } label: {
                            Text("\(days.count) days worn")
                                .font(.system(size: countFontSize, weight: .semibold))
                                .foregroundStyle(Color(uiColor: .label))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 36)
                                .frame(maxWidth: .infinity, minHeight: headerHeight)
                                .overlay(alignment: .trailing) {
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary).padding(.trailing, 16)
                                }
                                .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
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
                ForEach(days, id: \.day) { group in
                    Section {
                        ForEach(group.entries) { log in
                            if let owner = log.timepiece {
                                Button { editing = log } label: {
                                    HStack(spacing: 12) {
                                        PhotoView(photo: owner.mainPhoto.map { PhotoDraft(id: $0.id, filename: $0.filename) }, store: store.photoStore)
                                            .frame(width: 50, height: 58).clipShape(RoundedRectangle(cornerRadius: 8))
                                        VStack(alignment: .leading) {
                                            Text(owner.brand).font(.system(size: brandFontSize)).foregroundStyle(Color(uiColor: .label))
                                            Text(owner.modelName)
                                                .font(.system(size: modelFontSize, weight: .semibold))
                                                .foregroundStyle(Color("WatchModelGold"))
                                                .fixedSize(horizontal: false, vertical: true)
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
                        if let date = WearDay(key: group.day)?.date() {
                            Text(date.formatted(date: .complete, time: .omitted))
                                .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 3, trailing: 16))
                        }
                    }
                }
            }
        }
        .listSectionSpacing(12)
        .navigationTitle(watch == nil ? Text("Wearing") : Text("Wear overview"))
        .sheet(isPresented: $adding) {
            WearEditorView(store: store, initialWatch: watch ?? watches.first { $0.id == filterID })
        }
        .sheet(isPresented: $showingStatistics) {
            WearStatisticsView(initialWatchID: filterID)
        }
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

    private var addDaysButton: some View {
        Button { adding = true } label: {
            Label("Add wear days", systemImage: "plus")
                .font(.headline)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: headerHeight)
                .foregroundStyle(Color.accentColor)
                .background(Color.accentColor.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(watches.isEmpty)
        .opacity(watches.isEmpty ? 0.5 : 1)
        .accessibilityIdentifier("wear.add")
    }
}

struct WearEditorView: View {
    let store: CollectionStore
    var log: WearLog?
    @Query(sort: \Timepiece.brand) private var watches: [Timepiece]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @State private var watchID: UUID?
    @State private var date: Date
    @State private var selectedDays: Set<DateComponents> = []
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
                if log != nil {
                    DatePicker("Day", selection: $date, in: ...Date.now, displayedComponents: .date)
                } else {
                    Section {
                        MultiDatePicker("Wear days", selection: $selectedDays, in: ..<selectionEnd)
                            .accessibilityIdentifier("wear.days")
                        Text("Selected days: \(selectedDays.count)")
                            .accessibilityIdentifier("wear.selectionCount")
                    } footer: {
                        Text("Select one or more days. Existing entries for this watch will be skipped.")
                    }
                }
                Text("You can log several watches per day, once per watch. Archived watches can be logged for past days.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .navigationTitle(log == nil ? Text("Add wear days") : Text("Edit wear day"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            guard let watch = watches.first(where: { $0.id == watchID }) else {
                                throw WearError.missingWatch
                            }
                            if let log {
                                try store.logWear(for: watch, date: date, editing: log)
                            } else {
                                let dates = selectedDays.compactMap { calendar.date(from: $0) }
                                guard dates.count == selectedDays.count else { return }
                                try store.logWear(for: watch, dates: dates, timeZone: calendar.timeZone)
                            }
                            dismiss()
                        }
                        catch { self.error = error.localizedDescription }
                    }
                    .disabled(watchID == nil || (log == nil && selectedDays.isEmpty)).accessibilityIdentifier("wear.save")
                }
            }
            .appError($error)
        }
    }

    private var selectionEnd: Date {
        let today = calendar.startOfDay(for: .now)
        if let watch = watches.first(where: { $0.id == watchID }), watch.status != .owned {
            return today.addingTimeInterval(-1)
        }
        return .now
    }
}


private struct WearSummaryView: View {
    let dayKeys: Set<String>
    @Environment(\.locale) private var locale
    @State private var monthOffset = 0

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = locale
        value.firstWeekday = Calendar.current.firstWeekday
        return value
    }

    private var currentMonth: Date {
        calendar.dateInterval(of: .month, for: .now)!.start
    }

    private var displayedMonth: Date {
        calendar.date(byAdding: .month, value: monthOffset, to: currentMonth)!
    }

    private var dates: [Date] {
        (calendar.range(of: .day, in: .month, for: displayedMonth) ?? 1..<1).compactMap {
            calendar.date(byAdding: .day, value: $0 - 1, to: displayedMonth)
        }
    }

    private var leadingDays: Int {
        (calendar.component(.weekday, from: displayedMonth) - calendar.firstWeekday + 7) % 7
    }

    private var daysThisMonth: Int {
        guard let interval = calendar.dateInterval(of: .month, for: .now) else { return 0 }
        return dayKeys.compactMap { WearDay(key: $0)?.date() }.filter { interval.contains($0) }.count
    }

    var body: some View {
        Section("Summary") {
            LabeledContent("Total") { Text("\(dayKeys.count) days worn").fontWeight(.semibold) }
            LabeledContent("This month") { Text("\(daysThisMonth) days worn") }
            LabeledContent("Last worn") {
                if let key = dayKeys.max(), let date = WearDay(key: key)?.date() {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                } else { Text("Not yet worn") }
            }
        }
        Section("Wear calendar") {
            VStack(spacing: 16) {
                HStack {
                    Button { monthOffset -= 1 } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Previous month")
                    .accessibilityIdentifier("wear.month.previous")
                    Spacer(minLength: 0)
                    Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                        .font(.headline).multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("wear.month.title")
                    Spacer(minLength: 0)
                    Button { monthOffset += 1 } label: {
                        Image(systemName: "chevron.right").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Next month")
                    .accessibilityIdentifier("wear.month.next")
                    .disabled(monthOffset >= 0)
                }
                .buttonStyle(.borderless)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 8) {
                    ForEach(0..<7, id: \.self) { index in
                        Text(calendar.veryShortStandaloneWeekdaySymbols[(calendar.firstWeekday - 1 + index) % 7])
                            .font(.caption).foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    ForEach(0..<leadingDays, id: \.self) { _ in
                        Color.clear.frame(height: 32).accessibilityHidden(true)
                    }
                    ForEach(dates, id: \.self) { date in
                        let worn = dayKeys.contains(WearDay(date).key)
                        Text("\(calendar.component(.day, from: date))")
                            .font(.subheadline.weight(worn ? .bold : .regular))
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .foregroundStyle(worn ? Color.accentColor : Color.primary)
                            .background(worn ? Color.accentColor.opacity(0.2) : Color.clear, in: Circle())
                            .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                            .accessibilityValue(worn ? Text("Worn") : Text("Not worn"))
                    }
                }
                Label("Highlighted days indicate wear", systemImage: "circle.fill")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}


private struct WearStatisticsView: View {
    let initialWatchID: UUID?
    @Query private var logs: [WearLog]
    @Query(sort: \Timepiece.brand) private var watches: [Timepiece]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var period: WearStatistics.Period = .month
    @State private var selectedID: UUID?

    private var statistics: WearStatistics {
        WearStatistics(entries: logs.compactMap { log in
            log.timepiece.map { WearStatistics.Entry(watchID: $0.id, day: log.calendarDay) }
        }, period: period)
    }

    private func ranked(using stats: WearStatistics) -> [Timepiece] {
        watches.sorted {
            let left = stats.daysByWatch[$0.id, default: 0]
            let right = stats.daysByWatch[$1.id, default: 0]
            if left != right { return left > right }
            return "\($0.brand) \($0.modelName) \($0.id)" < "\($1.brand) \($1.modelName) \($1.id)"
        }
    }

    var body: some View {
        let stats = statistics
        let ranking = ranked(using: stats)
        let selected = watches.first { $0.id == (selectedID ?? initialWatchID) } ?? ranking.first
        let count = selected.map { stats.daysByWatch[$0.id, default: 0] } ?? 0
        let share = selected.map { stats.shareOfRecordedDays(for: $0.id) } ?? 0
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Picker("Period", selection: $period) {
                        Text("30 days").tag(WearStatistics.Period.month)
                        Text("This year").tag(WearStatistics.Period.year)
                        Text("All time").tag(WearStatistics.Period.all)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("stats.period")

                    if watches.isEmpty {
                        ContentUnavailableView("No wear history yet", systemImage: "chart.bar")
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("Watch", selection: Binding(get: { selected?.id }, set: { selectedID = $0 })) {
                                ForEach(watches) { watch in
                                    Text("\(watch.brand) \(watch.modelName)").tag(Optional(watch.id))
                                }
                            }
                            .tint(.accentColor)
                            .accessibilityIdentifier("stats.watch")
                            Text(selected?.modelName ?? "")
                                .font(.largeTitle.weight(.semibold))
                            Text("\(count) days worn")
                                .font(.title2.weight(.semibold)).monospacedDigit()
                                .contentTransition(.numericText())
                            Text("\(stats.start.formatted(date: .abbreviated, time: .omitted)) – \(Date.now.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption).foregroundStyle(.secondary)
                        }

                        if stats.recordedDays == 0 {
                            ContentUnavailableView("No entries in this period", systemImage: "calendar")
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Share of recorded days").font(.headline)
                                Chart {
                                    SectorMark(angle: .value("Days", count), innerRadius: .ratio(0.78), angularInset: 2)
                                        .foregroundStyle(Color.accentColor)
                                    SectorMark(angle: .value("Days", stats.recordedDays - count), innerRadius: .ratio(0.78), angularInset: 2)
                                        .foregroundStyle(Color.secondary.opacity(0.18))
                                }
                                .frame(height: 210)
                                .chartBackground { _ in
                                    VStack(spacing: 4) {
                                        Text(share, format: .percent.precision(.fractionLength(0)))
                                            .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                                            .monospacedDigit().contentTransition(.numericText())
                                        Text("of recorded days").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Share of recorded days")
                                .accessibilityValue(share.formatted(.percent.precision(.fractionLength(0))))
                                HStack {
                                    Label("Selected watch", systemImage: "circle.fill").foregroundStyle(Color.accentColor)
                                    Spacer()
                                    Text("Days without selected watch").foregroundStyle(.secondary)
                                }
                                .font(.caption)
                                Text("\(count) of \(stats.recordedDays) recorded days")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Against calendar days").font(.headline)
                            HStack(alignment: .firstTextBaseline) {
                                Text(Double(count) / Double(stats.calendarDays), format: .percent.precision(.fractionLength(0)))
                                    .font(.title2.weight(.semibold)).monospacedDigit()
                                Text("\(count) of \(stats.calendarDays) calendar days")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }

                        Divider()
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Watch comparison").font(.title2.weight(.semibold))
                            ForEach(ranking) { watch in
                                let days = stats.daysByWatch[watch.id, default: 0]
                                Button { selectedID = watch.id } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(alignment: .firstTextBaseline) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(watch.brand).font(.caption).foregroundStyle(.secondary)
                                                Text(watch.modelName).font(.headline).foregroundStyle(Color(uiColor: .label))
                                            }
                                            Spacer()
                                            Text("\(days) days worn").font(.subheadline).monospacedDigit()
                                                .foregroundStyle(Color(uiColor: .secondaryLabel))
                                        }
                                        Chart {
                                            BarMark(x: .value("Days", days), y: .value("Watch", ""))
                                                .cornerRadius(4)
                                                .foregroundStyle(Color.accentColor.opacity(watch.id == selected?.id ? 1 : 0.4))
                                        }
                                        .chartXScale(domain: 0...max(stats.daysByWatch.values.max() ?? 0, 1))
                                        .chartXAxis(.hidden).chartYAxis(.hidden)
                                        .frame(height: 12).accessibilityHidden(true)
                                    }
                                    .padding(.vertical, 4)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(watch.id == selected?.id ? .isSelected : [])
                                .accessibilityHint("Select watch for statistics")
                            }
                        }
                    }
                }
                .padding(20)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: period)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: selectedID)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Wear statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
