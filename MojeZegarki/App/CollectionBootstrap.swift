import Foundation
import OSLog

@MainActor final class CollectionBootstrap {
    private let configuration: AppLaunchConfiguration
    private var resetPrepared = false
    private let openStore: @MainActor (URL?) async throws -> CollectionStore
    private let reconcile: @MainActor (CollectionStore) async throws -> Void

    init(
        configuration: AppLaunchConfiguration = AppLaunchConfiguration(),
        openStore: @escaping @MainActor (URL?) async throws -> CollectionStore = {
            try await CollectionStore.open(directory: $0)
        },
        reconcile: @escaping @MainActor (CollectionStore) async throws -> Void = { try await $0.reconcileAssets() }
    ) {
        self.configuration = configuration
        self.openStore = openStore
        self.reconcile = reconcile
    }

    func load() async throws -> CollectionStore {
        if !resetPrepared, configuration.has("--reset-test-store"), let directory = configuration.directory {
            try await CollectionStorage().resetTestDirectory(directory)
            resetPrepared = true
        }
        let store = try await openStore(configuration.directory)
        // Editors must not import new files while this snapshot is being reconciled.
        do { try await reconcile(store) } catch {
            Logger(subsystem: "pl.jakubbatycki.MojeZegarki", category: "Storage").error(
                "Asset cleanup failed: \(error, privacy: .private)")
        }
        try Task.checkCancellation()
        #if DEBUG
            if configuration.isUITesting, let directory = configuration.directory {
                try await UITestFixtures(configuration: configuration, directory: directory).seed(in: store)
            }
        #endif
        return store
    }
}
