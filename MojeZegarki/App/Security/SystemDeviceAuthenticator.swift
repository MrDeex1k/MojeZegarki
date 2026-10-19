import LocalAuthentication

@MainActor
final class SystemDeviceAuthenticator: DeviceAuthenticating {
    private var context: LAContext?
    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        self.context = context
        defer { self.context = nil }
        var failure: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &failure) else {
            throw failure ?? NSError(domain: LAError.errorDomain, code: LAError.passcodeNotSet.rawValue)
        }
        return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
    }
    func invalidate() { context?.invalidate() }
}
