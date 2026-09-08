import SwiftUI

struct SettingsView: View {
    let lock: AppLock
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Lock collection", isOn: Binding(get: { lock.enabled }, set: { enabled in Task { await lock.setEnabled(enabled) } }))
                        .disabled(lock.isBusy).accessibilityIdentifier("settings.lock")
                    if lock.enabled { Button("Lock now", systemImage: "lock") { lock.lock() } }
                    if lock.isBusy { ProgressView() }
                    if let error = lock.error { Text(error).foregroundStyle(.red).font(.footnote) }
                } header: { Text("Privacy") } footer: {
                    Text("Require Face ID or the device passcode when returning to the app. Your collection is hidden in the app switcher.")
                }
                Section("Language") {
                    Text("The app follows your preferred language. Polish and English are supported.")
                    Button("Open system settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                    Text("Your collection is stored on this iPhone and works offline.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
