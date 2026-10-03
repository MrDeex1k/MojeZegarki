import SwiftData
import SwiftUI

struct WearTodayButton: View {
    let watch: Timepiece
    let store: CollectionStore
    var compact = false
    var sharedLogged: Bool?

    var body: some View {
        if let sharedLogged {
            WearActionButton(watch: watch, store: store, compact: compact, logged: sharedLogged)
        } else {
            TimelineView(.periodic(from: Date(timeIntervalSince1970: 0), by: 60)) { timeline in
                let today = WearDay(timeline.date).key
                WearTodayDayButton(watch: watch, store: store, compact: compact, day: today)
                    .id(today)
            }
        }
    }
}

private struct WearTodayDayButton: View {
    let watch: Timepiece
    let store: CollectionStore
    let compact: Bool
    let day: String
    @Query private var logs: [WearLog]

    init(watch: Timepiece, store: CollectionStore, compact: Bool, day: String) {
        self.watch = watch
        self.store = store
        self.compact = compact
        self.day = day
        let watchID = watch.id
        _logs = Query(
            filter: #Predicate<WearLog> {
                $0.timepiece?.id == watchID && $0.calendarDay == day
            })
    }

    var body: some View {
        WearActionButton(watch: watch, store: store, compact: compact, logged: !logs.isEmpty)
    }
}

private struct WearActionButton: View {
    let watch: Timepiece
    let store: CollectionStore
    let compact: Bool
    let logged: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var error: String?

    var body: some View {
        Button {
            do { try store.logWear(for: watch, date: .now) } catch { self.error = error.localizedDescription }
        } label: {
            if compact {
                Image(systemName: logged ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.title2).frame(width: 44, height: 44)
            } else {
                Label(
                    logged ? "Worn today" : "Wearing today",
                    systemImage: logged ? "checkmark.circle.fill" : "checkmark.circle"
                )
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

/// One day-scoped query per collection, instead of one query and timer per row.
struct TodayWearScope<Content: View>: View {
    @Query private var logs: [WearLog]
    let content: (Set<UUID>) -> Content
    init(day: String, @ViewBuilder content: @escaping (Set<UUID>) -> Content) {
        _logs = Query(filter: #Predicate<WearLog> { $0.calendarDay == day })
        self.content = content
    }
    var body: some View { content(Set(logs.compactMap { $0.timepiece?.id })) }
}
