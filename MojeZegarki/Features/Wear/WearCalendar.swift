import SwiftUI

/// Gregorian day keys are shared with persistence; locale only changes presentation.
struct WearCalendar: View {
    var counts: [String: Int] = [:]
    var pending: Set<String> = []
    var selectedDay: String?
    var editing = false
    var singleWatch = false
    var allowsToday = true
    var enabled = true
    let onSelect: (String) -> Void
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var month = Calendar(identifier: .gregorian).dateInterval(of: .month, for: .now)!.start
    @State private var jumping = false

    private var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.locale = locale
        result.firstWeekday = Calendar.current.firstWeekday
        return result
    }
    private var dates: [Date] {
        let start = calendar.dateInterval(of: .month, for: month)!.start
        return (calendar.range(of: .day, in: .month, for: start) ?? 1..<1).compactMap {
            calendar.date(byAdding: .day, value: $0 - 1, to: start)
        }
    }
    private var identifierPrefix: String { editing ? "wear.selection" : "wear" }

    private var today: String { WearDay(.now).key }
    private var currentMonth: Date { calendar.dateInterval(of: .month, for: .now)!.start }

    var body: some View {
        VStack(spacing: 12) {
            if typeSize.isAccessibilitySize {
                monthButton
                HStack {
                    previousButton
                    Spacer()
                    nextButton
                }.buttonStyle(.borderless)
            } else {
                HStack {
                    previousButton
                    Spacer(minLength: 0)
                    monthButton
                    Spacer(minLength: 0)
                    nextButton
                }.buttonStyle(.borderless)
            }
            if month < currentMonth {
                Button("Today") { month = currentMonth }.buttonStyle(.borderless)
            }
            if typeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    ForEach(dates, id: \.self) { day in dayButton(day, expanded: true) }
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 6) {
                    ForEach(0..<7, id: \.self) { index in
                        Text(calendar.veryShortStandaloneWeekdaySymbols[(calendar.firstWeekday - 1 + index) % 7])
                            .font(.caption).foregroundStyle(.secondary).accessibilityHidden(true)
                    }
                    ForEach(
                        0..<((calendar.component(.weekday, from: dates.first ?? month) - calendar.firstWeekday + 7) % 7),
                        id: \.self
                    ) { _ in
                        Color.clear.frame(height: 44).accessibilityHidden(true)
                    }
                    ForEach(dates, id: \.self) { day in dayButton(day, expanded: false) }
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack { legend }
                VStack(alignment: .leading) { legend }
            }.font(.caption).foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .sheet(isPresented: $jumping) {
            NavigationStack {
                Form {
                    DatePicker("Jump to date", selection: $month, in: ...Date.now, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }
                .navigationTitle("Choose month and year")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            month = calendar.dateInterval(of: .month, for: month)!.start
                            jumping = false
                        }
                    }
                }
            }.presentationDetents([.medium, .large])
        }
    }

    private var monthButton: some View {
        Button {
            jumping = true
        } label: {
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.headline).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44)
        }.buttonStyle(.borderless)
            .accessibilityIdentifier("\(identifierPrefix).month.title").accessibilityHint("Choose month and year")
    }
    private var previousButton: some View {
        Button {
            move(-1)
        } label: {
            Image(systemName: "chevron.left").font(.system(size: 20)).frame(width: 44, height: 44)
        }
        .accessibilityLabel("Previous month").accessibilityIdentifier("\(identifierPrefix).month.previous")
    }
    private var nextButton: some View {
        Button {
            move(1)
        } label: {
            Image(systemName: "chevron.right").font(.system(size: 20)).frame(width: 44, height: 44)
        }
        .disabled(month >= currentMonth).accessibilityLabel("Next month").accessibilityIdentifier(
            "\(identifierPrefix).month.next")
    }

    @ViewBuilder private var legend: some View {
        if editing || singleWatch {
            Label("Already worn", systemImage: "checkmark.circle.fill")
            if editing { Label("New day", systemImage: "plus.circle") }
        } else {
            Text("Number below the date: watches worn")
        }
    }

    private func dayButton(_ date: Date, expanded: Bool) -> some View {
        let key = WearDay(date).key
        let count = counts[key, default: 0]
        let saved = count > 0
        let isPending = pending.contains(key)
        let unavailable = key > today || (editing && (!enabled || (key == today && !allowsToday) || saved))
        return Button {
            onSelect(key)
        } label: {
            (expanded ? AnyLayout(HStackLayout(spacing: 8)) : AnyLayout(VStackLayout(spacing: 0))) {
                Text(
                    expanded
                        ? date.formatted(.dateTime.day().month().weekday(.wide))
                        : "\(calendar.component(.day, from: date))"
                )
                .font(expanded ? .body : .callout)
                if expanded { Spacer(minLength: 0) }
                if saved && (editing || singleWatch) {
                    Image(systemName: "checkmark").font(.caption2)
                } else if isPending {
                    Image(systemName: "plus").font(.caption2)
                } else if saved {
                    Text("\(count)").font(.caption2)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, expanded ? 8 : 0)
            .foregroundStyle(unavailable && !saved ? Color.secondary : Color.primary)
            .background(
                saved ? Color.accentColor.opacity(0.2) : isPending ? Color.accentColor.opacity(0.1) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10).strokeBorder(
                    isPending || selectedDay == key ? Color.accentColor : Color.clear, lineWidth: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(unavailable)
        .accessibilityIdentifier("\(identifierPrefix).day.\(key)")
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(
            saved
                ? (singleWatch || editing ? Text("Already worn") : Text("Watches: \(count)"))
                : isPending ? Text("New day") : Text("Not yet worn")
        )
        .accessibilityAddTraits(isPending || selectedDay == key ? .isSelected : [])
    }

    private func move(_ offset: Int) {
        month = calendar.date(byAdding: .month, value: offset, to: month) ?? month
    }
}
