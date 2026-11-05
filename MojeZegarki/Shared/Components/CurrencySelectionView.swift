import SwiftUI

struct CurrencySelectionView: View {
    @Binding var selection: String
    @Environment(\.locale) private var locale
    @State private var search = ""

    var body: some View {
        let preferred = CurrencyPreference.defaultCode(for: locale)
        let supported = Locale.commonISOCurrencyCodes
        let legacy = !selection.isEmpty && !supported.contains(selection) ? [selection] : []
        let codes = legacy + [preferred] + supported.filter { $0 != preferred }.sorted()
        let term = search.trimmed
        let matches = codes.filter { code in
            term.isEmpty
                || label(for: code).range(of: term, options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
                    != nil
        }
        List {
            if term.isEmpty { row("", title: Text("Not specified")) }
            ForEach(matches, id: \.self) { code in
                row(code, title: Text(verbatim: label(for: code)))
            }
            if !term.isEmpty && matches.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search currencies")
        .navigationTitle("Currency")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func label(for code: String) -> String {
        guard let name = locale.localizedString(forCurrencyCode: code), name != code else { return code }
        return "\(code) — \(name)"
    }

    private func row(_ code: String, title: Text) -> some View {
        Button {
            selection = code
        } label: {
            HStack {
                title.foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if selection == code {
                    Image(systemName: "checkmark").accessibilityHidden(true)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(selection == code ? .isSelected : [])
        .accessibilityIdentifier(code.isEmpty ? "currency.none" : "currency.\(code)")
    }
}
