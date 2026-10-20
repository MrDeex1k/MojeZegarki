import SwiftData
import SwiftUI

struct WearActionButton: View {
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
