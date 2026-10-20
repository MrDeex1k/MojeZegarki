import SwiftUI

struct SettingsView: View {
    let lock: AppLock
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(
                        "Lock collection",
                        isOn: Binding(
                            get: { lock.enabled }, set: { enabled in Task { await lock.setEnabled(enabled) } })
                    )
                    .disabled(lock.isBusy).accessibilityIdentifier("settings.lock")
                    if lock.enabled { Button("Lock now", systemImage: "lock") { lock.lock() } }
                    if lock.isBusy { ProgressView() }
                    if let error = lock.error { Text(error).foregroundStyle(.red).font(.footnote) }
                } header: {
                    Text("Privacy").foregroundStyle(Color(uiColor: .label))
                } footer: {
                    Text(
                        "Require Face ID or the device passcode when returning to the app. Your collection is hidden in the app switcher."
                    ).foregroundStyle(Color(uiColor: .label))
                }
                Section {
                    Text("The app follows your preferred language. Polish and English are supported.")
                    Button("Open system settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                } header: {
                    Text("Language").foregroundStyle(Color(uiColor: .label))
                }
                Section {
                    LabeledContent {
                        Text(
                            verbatim:
                                Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
                        )
                        .foregroundStyle(Color.supportingText)
                    } label: {
                        Text("Version")
                    }
                } header: {
                    Text("About").foregroundStyle(Color(uiColor: .label))
                }
            }
            .navigationTitle("Settings")
        }
    }
}
