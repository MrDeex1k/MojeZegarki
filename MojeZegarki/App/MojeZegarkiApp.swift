import SwiftUI

@main
struct MojeZegarkiApp: App {
    @State private var store: CollectionStore?
    @State private var failure = false
    @State private var lock: AppLock

    init() {
        var defaults = UserDefaults.standard
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting"), let testDefaults = UserDefaults(suiteName: "CollectionUITests") {
            defaults = testDefaults
            if ProcessInfo.processInfo.arguments.contains("--reset-test-store") { defaults.removePersistentDomain(forName: "CollectionUITests") }
            if ProcessInfo.processInfo.arguments.contains("--test-lock-enabled") { defaults.set(true, forKey: "appLockEnabled") }
        }
        #endif
        _lock = State(initialValue: AppLock(defaults: defaults))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let store {
                    RootView(store: store, lock: lock).modelContainer(store.container)
                } else if failure {
                    ContentUnavailableView {
                        Label("Could not open collection", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text("Your data has not been reset. Check available storage and try again.")
                    } actions: {
                        Button("Try again") { Task { await load() } }
                    }
                } else {
                    ProgressView("Opening collection…")
                }
            }
            .tint(Color("AccentColor"))
            .background { LockShield(lock: lock, enabled: lock.enabled, isLocked: lock.isLocked).frame(width: 0, height: 0) }
            .task { if store == nil && !failure { await load() } }
        }
    }

    @MainActor
    private func load() async {
        failure = false
        do {
            var directory: URL?
            #if DEBUG
            // UI tests use an isolated on-disk store, never the user's collection.
            if ProcessInfo.processInfo.arguments.contains("--uitesting") {
                directory = FileManager.default.temporaryDirectory.appendingPathComponent("CollectionUITests")
                if ProcessInfo.processInfo.arguments.contains("--reset-test-store"), let directory,
                   FileManager.default.fileExists(atPath: directory.path) {
                    try FileManager.default.removeItem(at: directory)
                }
            }
            #endif
            let loaded = try CollectionStore(directory: directory)
            try await loaded.reconcilePhotos()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--uitesting"),
               ProcessInfo.processInfo.arguments.contains("--test-document-fixture") {
                try await seedDocumentFixture(in: loaded)
            }
            #endif
            store = loaded
        } catch { failure = true }
    }

    #if DEBUG
    @MainActor private func seedDocumentFixture(in store: CollectionStore) async throws {
        var draft = TimepieceDraft()
        draft.brand = "TestBrand"
        draft.modelName = "Document watch"
        let watch = try store.save(draft)
        let pdf = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 600)).pdfData { context in
            context.beginPage()
            ("Test invoice / 2026" as NSString).draw(at: CGPoint(x: 30, y: 30), withAttributes: nil)
        }
        let asset = try await store.documentStore.importData(pdf)
        try store.attachDocument(asset, to: watch, name: "Test invoice", kind: .purchase, date: nil, notes: "Private test document")
    }
    #endif
}
