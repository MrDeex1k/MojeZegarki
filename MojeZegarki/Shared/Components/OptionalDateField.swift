import SwiftUI

struct OptionalDateField: View {
    let toggleTitle: LocalizedStringKey
    let dateTitle: LocalizedStringKey
    @Binding var selection: Date?

    var body: some View {
        Toggle(toggleTitle, isOn: Binding(get: { selection != nil }, set: { selection = $0 ? .now : nil }))
        if selection != nil {
            DatePicker(
                dateTitle, selection: Binding(get: { selection ?? .now }, set: { selection = $0 }),
                displayedComponents: .date)
        }
    }
}
