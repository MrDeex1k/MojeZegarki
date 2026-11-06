import LocalAuthentication

@MainActor
final class SystemDeviceAuthenticator: DeviceAuthenticating {
    private var context: LAContext?
    private var requestID: UUID?
    /// Owns the authentication context for this request and invalidates it on cancellation.
    func authenticate(reason: String) async throws -> Bool {
        try Task.checkCancellation()
        self.context?.invalidate()
        let context = LAContext()
        let id = UUID()
        requestID = id
        self.context = context
        defer {
            if requestID == id {
                self.context = nil
                requestID = nil
            }
        }
        var failure: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &failure) else {
            throw failure ?? NSError(domain: LAError.errorDomain, code: LAError.passcodeNotSet.rawValue)
        }
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            let result = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            try Task.checkCancellation()
            return result
        } onCancel: {
            Task { @MainActor [weak self] in
                if self?.requestID == id { self?.invalidate() }
            }
        }
    }
    func invalidate() { context?.invalidate() }
}
