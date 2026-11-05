import Foundation
import Observation

@MainActor @Observable
final class DraftAssetSession {
    private(set) var isImporting = false
    private(set) var importedCount = 0
    @ObservationIgnored private var stagedIDs: Set<UUID> = []
    private(set) var isFinished = false
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let remove: @Sendable (UUID) async throws -> Void

    init(remove: @escaping @Sendable (UUID) async throws -> Void) {
        self.remove = remove
    }

    func run(_ operation: @escaping @MainActor () async -> Void) {
        guard !isImporting, !isFinished else { return }
        isImporting = true
        importedCount = 0
        task = Task { [weak self] in
            defer {
                self?.isImporting = false
                self?.task = nil
            }
            guard !Task.isCancelled else { return }
            await operation()
        }
    }

    func stop() { task?.cancel() }

    // The owning editor session claims an import as soon as it receives it, even
    // if presentation is cancelled. Do not claim shared files from view initializers.
    func claim(_ id: UUID) {
        guard !isFinished else { return }
        stagedIDs.insert(id)
    }

    func stage(_ id: UUID) async -> Bool {
        guard !Task.isCancelled, !isFinished else {
            try? await remove(id)
            return false
        }
        stagedIDs.insert(id)
        importedCount += 1
        return true
    }

    func commit(retaining: Set<UUID>, replacing: Set<UUID> = []) async {
        guard !isFinished else { return }
        isFinished = true
        let discarded = stagedIDs.union(replacing).subtracting(retaining)
        stagedIDs.removeAll()
        for id in discarded { try? await remove(id) }
    }

    deinit {
        task?.cancel()
        let abandoned = stagedIDs
        let remove = remove
        Task { for id in abandoned { try? await remove(id) } }
    }
}
