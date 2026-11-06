import Observation

/// Owns initialization independently of SwiftUI's cancellable presentation tasks.
@MainActor @Observable
final class StartupController<Resource> {
    enum State {
        case waiting, loading
        case ready(Resource)
        case failed(StartupFailure)
    }

    private(set) var state: State = .waiting
    @ObservationIgnored private var available = false
    @ObservationIgnored private var attempt: Task<Void, Never>?
    @ObservationIgnored private let load: @MainActor () async throws -> Resource

    init(load: @escaping @MainActor () async throws -> Resource) { self.load = load }

    var resource: Resource? {
        if case .ready(let resource) = state { resource } else { nil }
    }

    var failure: StartupFailure? {
        if case .failed(let failure) = state { failure } else { nil }
    }

    /// Pauses startup while protected files are inaccessible and restarts it after an unlock when needed.
    func setDataAvailable(_ value: Bool) {
        available = value
        guard resource == nil else { return }
        if !value {
            attempt?.cancel()
            // The failed file access may arrive before the protected-data notification.
            if failure == nil || failure?.kind == .unavailable { state = .waiting }
        } else {
            startIfNeeded()
        }
    }

    /// Clears a displayed failure and requests another attempt when protected data is accessible.
    func retry() {
        guard resource == nil else { return }
        state = .waiting
        startIfNeeded()
    }

    /// Serializes attempts, including a replacement requested while cancellation is still in flight.
    private func startIfNeeded() {
        guard available, attempt == nil, resource == nil, failure == nil else { return }
        state = .loading
        attempt = Task {
            do {
                let resource = try await load()
                if available && !Task.isCancelled { state = .ready(resource) } else { state = .waiting }
            } catch {
                if available && !Task.isCancelled {
                    state = .failed(StartupFailure(error: error))
                } else {
                    state = .waiting
                }
            }
            attempt = nil
            // An unlock may have requested a retry while the cancelled attempt was still finishing.
            startIfNeeded()
        }
    }

    /// Waits for the current attempt and any replacement it starts while settling.
    func waitUntilSettled() async {
        while let attempt { await attempt.value }
    }
}
