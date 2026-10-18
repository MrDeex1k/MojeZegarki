import SwiftData
import SwiftUI

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
    @State private var selectedDay: String?
    @State private var scrollRequest = UUID()
    @ScaledMetric(relativeTo: .title3) private var countFontSize = 20
    @State private var filterID: UUID?
    @State private var error: String?
    @State private var savedCount: Int?
    @StateObject private var scrollBehavior = WearScrollBehavior()
    @Environment(\.dynamicTypeSize) private var typeSize

    init(store: CollectionStore, watch: Timepiece? = nil) {
        self.store = store
        self.watch = watch
        if let id = watch?.id {
            _logs = Query(
                filter: #Predicate<WearLog> { $0.timepiece?.id == id }, sort: \WearLog.calendarDay, order: .reverse)
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
                        Menu {
                            Picker("Watch", selection: $filterID) {
                                Text("All watches").tag(Optional<UUID>.none)
                                ForEach(watches) { Text("\($0.brand) \($0.modelName)").tag(Optional($0.id)) }
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Watch").font(.caption).foregroundStyle(.secondary)
                                    if let selected = watches.first(where: { $0.id == filterID }) {
                                        Text("\(selected.brand) \(selected.modelName)")
                                    } else {
                                        Text("All watches")
                                    }
                                }.multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.up.chevron.down").font(.caption)
                            }.padding(.vertical, 10)
                        }.accessibilityIdentifier("wear.filter")
                            .padding(.horizontal, 16)
                            .frame(minHeight: headerHeight)
                            .background(
                                Color(uiColor: .secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: typeSize.isAccessibilitySize ? 16 : 28)
                            )
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
                    } actions: {
                        addDaysButton
                    }
                    .listRowBackground(Color.clear)
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
                                            .foregroundStyle(.secondary).padding(.trailing, 16)
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
                        Text("Wear calendar")
                    } footer: {
                        if selectedDay == nil {
                            Text("Select a day to see worn watches")
                                .accessibilityIdentifier("wear.calendarHint")
                        }
                    }
                    if selectedDay != nil, !days.contains(where: { $0.day == selectedDay }) {
                        Text("No wear entries for this day")
                            .foregroundStyle(.secondary).listRowBackground(Color.clear)
                            .id(selectedDay)
                    }
                    ForEach(days.filter { $0.day == selectedDay }, id: \.day) { group in
                        Section {
                            ForEach(group.entries) { log in
                                if let owner = log.timepiece {
                                    Button {
                                        editing = log
                                    } label: {
                                        (typeSize.isAccessibilitySize
                                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                                            : AnyLayout(HStackLayout(spacing: 12))) {
                                                PhotoView(
                                                    photo: owner.mainPhoto.map {
                                                        PhotoDraft(id: $0.id, filename: $0.filename)
                                                    }, store: store.photoStore
                                                )
                                                .frame(width: 50, height: 58).clipShape(
                                                    RoundedRectangle(cornerRadius: 8))
                                                VStack(alignment: .leading) {
                                                    Text(owner.brand).font(.system(size: brandFontSize))
                                                        .foregroundStyle(Color(uiColor: .label))
                                                    Text(owner.modelName)
                                                        .font(.system(size: modelFontSize, weight: .semibold))
                                                        .foregroundStyle(Color("WatchModelGold"))
                                                        .fixedSize(horizontal: false, vertical: true)
                                                    if owner.status != .owned {
                                                        Text(owner.status.title).font(.caption).foregroundStyle(
                                                            .secondary)
                                                    }
                                                }
                                                Spacer()
                                                Image(systemName: "pencil").foregroundStyle(.secondary)
                                            }
                                    }
                                    .accessibilityIdentifier("wear.log.\(log.id)")
                                    .id("wear.result.\(log.id)")
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
                // Wait for List to insert the selected day's rows before scrolling to a real result.
                await Task.yield()
                guard !Task.isCancelled else { return }
                let firstLog = filteredLogs.first { $0.calendarDay == selectedDay }
                withAnimation {
                    if let firstLog {
                        proxy.scrollTo("wear.result.\(firstLog.id)", anchor: .top)
                    } else {
                        proxy.scrollTo(Optional(selectedDay), anchor: .top)
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

/// Keep normal scrolling, but prevent elastic overscroll in the watch's wear sheet.
/// SwiftUI's basedOnSize still bounces when content exceeds the viewport by a few points.
@MainActor private final class WearScrollBehavior: ObservableObject {
    private weak var scrollView: UIScrollView?
    private var observation: NSKeyValueObservation?

    func attach(to scrollView: UIScrollView) {
        guard self.scrollView !== scrollView else {
            scrollView.bounces = false
            return
        }
        observation = nil
        self.scrollView = scrollView
        scrollView.bounces = false
        // SwiftUI can reapply its scroll configuration after selection or layout changes.
        // Retain this observation for the view's lifetime, including when the anchor's row is recycled.
        observation = scrollView.observe(\.bounces, options: [.new]) { scrollView, _ in
            MainActor.assumeIsolated {
                if scrollView.bounces { scrollView.bounces = false }
            }
        }
    }
}

private struct WearScrollAnchor: UIViewRepresentable {
    let behavior: WearScrollBehavior

    func makeUIView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.behavior = behavior
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: AnchorView, context: Context) {
        uiView.behavior = behavior
        // Apply after SwiftUI finishes updating the containing list.
        DispatchQueue.main.async { [weak uiView] in uiView?.attach() }
    }

    final class AnchorView: UIView {
        weak var behavior: WearScrollBehavior?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            attach()
        }

        func attach() {
            var ancestor = superview
            while let view = ancestor {
                if let scrollView = view as? UIScrollView {
                    behavior?.attach(to: scrollView)
                    return
                }
                ancestor = view.superview
            }
        }
    }
}
