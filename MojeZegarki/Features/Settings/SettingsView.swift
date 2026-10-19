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
                    Text(
                        "Your collection and attachments stay in this app and are included in system backups when enabled. There is no account or app sync."
                    )
                    Text(
                        "With a device passcode set, files are protected while your iPhone is locked. App Lock adds Face ID or device-passcode verification when returning to the app."
                    )
                } header: {
                    Text("Storage and backup").foregroundStyle(Color(uiColor: .label))
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
                                "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"))"
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
