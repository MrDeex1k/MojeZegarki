import Foundation

@MainActor
protocol DeviceAuthenticating {
    func authenticate(reason: String) async throws -> Bool
    func invalidate()
}
