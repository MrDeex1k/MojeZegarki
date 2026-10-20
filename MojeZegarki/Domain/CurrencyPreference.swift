import Foundation

enum CurrencyPreference {
    static func defaultCode(for locale: Locale) -> String {
        locale.language.languageCode?.identifier == "pl" ? "PLN" : "USD"
    }
}
