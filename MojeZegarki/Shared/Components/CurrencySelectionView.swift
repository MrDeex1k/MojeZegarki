import SwiftUI

struct CurrencySelectionView: View {
    @Binding var selection: String
    @Environment(\.locale) private var locale

    private var codes: [String] {
        let preferred = CurrencyPreference.defaultCode(for: locale)
        return [preferred] + Locale.commonISOCurrencyCodes.filter { $0 != preferred }.sorted()
    }

    var body: some View {
        Form {
            Picker("Currency", selection: $selection) {
                Text("Not specified").tag("")
                ForEach(codes, id: \.self) { code in
                    Text(verbatim: "\(code) — \(locale.localizedString(forCurrencyCode: code) ?? code)")
                        .fixedSize(horizontal: false, vertical: true).tag(code)
                }
            }
            .pickerStyle(.inline)
        }
        .navigationTitle("Currency")
        .navigationBarTitleDisplayMode(.inline)
    }
}
