import SwiftUI

struct LockScreen: View {
    let lock: AppLock
    let obscured: Bool
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield").font(.system(size: 54, weight: .light)).foregroundStyle(
                Color("AccentColor")
            )
            .accessibilityHidden(true)
            Text("Collection locked").font(.title2.bold())
            if !obscured {
                Text("Unlock with Face ID or your device passcode.").multilineTextAlignment(.center).foregroundStyle(
                    .secondary)
                if lock.isBusy {
                    ProgressView()
                } else {
                    Button("Unlock") { Task { await lock.unlock() } }
                        .buttonStyle(.borderedProminent).tint(Color("AccentColor"))
                        .accessibilityIdentifier("lock.unlock")
                }
                if let error = lock.error { Text(error).font(.footnote).multilineTextAlignment(.center) }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}
