import Charts
import SwiftData
import SwiftUI

struct WearStatisticsContent: View {
    let initialWatchID: UUID?
    let now: Date
    @Query private var logs: [WearLog]
    @Query(sort: \Timepiece.brand) private var watches: [Timepiece]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var period: WearStatistics.Period
    @State private var selectedID: UUID?

    init(
        initialWatchID: UUID?, period: Binding<WearStatistics.Period>, currentPeriod: WearStatistics.Period, now: Date
    ) {
        self.initialWatchID = initialWatchID
        self.now = now
        _period = period
        _logs = Query(filter: WearLogScope.period(currentPeriod, now: now))
    }

    private var statistics: WearStatistics {
        WearStatistics(
            entries: logs.compactMap { log in
                log.timepiece.map { WearStatistics.Entry(watchID: $0.id, day: log.calendarDay) }
            }, period: period, now: now)
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
        let maximum = max(stats.daysByWatch.values.max() ?? 0, 1)
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
                            Text(
                                "\(stats.start.formatted(date: .abbreviated, time: .omitted)) – \(Date.now.formatted(date: .abbreviated, time: .omitted))"
                            )
                            .font(.caption).foregroundStyle(Color.supportingText)
                        }

                        if stats.recordedDays == 0 {
                            ContentUnavailableView("No entries in this period", systemImage: "calendar")
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Share of recorded days").font(.headline)
                                Chart {
                                    SectorMark(angle: .value("Days", count), innerRadius: .ratio(0.78), angularInset: 2)
                                        .foregroundStyle(Color.accentColor)
                                    SectorMark(
                                        angle: .value("Days", stats.recordedDays - count), innerRadius: .ratio(0.78),
                                        angularInset: 2
                                    )
                                    .foregroundStyle(Color.secondary.opacity(0.18))
                                }
                                .frame(height: 210)
                                .chartBackground { _ in
                                    VStack(spacing: 4) {
                                        Text(share, format: .percent.precision(.fractionLength(0)))
                                            .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                                            .monospacedDigit().contentTransition(.numericText())
                                        Text("of recorded days").font(.caption).foregroundStyle(Color.supportingText)
                                    }
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Share of recorded days")
                                .accessibilityValue(share.formatted(.percent.precision(.fractionLength(0))))
                                HStack {
                                    Label("Selected watch", systemImage: "circle.fill").foregroundStyle(
                                        Color.accentColor)
                                    Spacer()
                                    Text("Days without selected watch").foregroundStyle(Color.supportingText)
                                }
                                .font(.caption)
                                Text("\(count) of \(stats.recordedDays) recorded days")
                                    .font(.subheadline).foregroundStyle(Color.supportingText)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Against calendar days").font(.headline)
                            HStack(alignment: .firstTextBaseline) {
                                Text(
                                    Double(count) / Double(stats.calendarDays),
                                    format: .percent.precision(.fractionLength(0))
                                )
                                .font(.title2.weight(.semibold)).monospacedDigit()
                                Text("\(count) of \(stats.calendarDays) calendar days")
                                    .font(.subheadline).foregroundStyle(Color.supportingText)
                            }
                        }

                        Divider()
                        LazyVStack(alignment: .leading, spacing: 20) {
                            Text("Watch comparison").font(.title2.weight(.semibold))
                            ForEach(ranking) { watch in
                                WatchStatisticsRow(
                                    watch: watch, days: stats.daysByWatch[watch.id, default: 0], maximum: maximum,
                                    isSelected: watch.id == selected?.id
                                ) { selectedID = watch.id }
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
