import OSLog
import SwiftUI

@main
struct MojeZegarkiApp: App {
    @State private var store: CollectionStore?
    @State private var failure = false
    @State private var lock: AppLock

    init() {
        var defaults = UserDefaults.standard
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--uitesting"),
                let testDefaults = UserDefaults(suiteName: "CollectionUITests")
            {
                defaults = testDefaults
                if ProcessInfo.processInfo.arguments.contains("--reset-test-store") {
                    defaults.removePersistentDomain(forName: "CollectionUITests")
                }
                if ProcessInfo.processInfo.arguments.contains("--test-lock-enabled") {
                    defaults.set(true, forKey: "appLockEnabled")
                }
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
            .preferredColorScheme(testColorScheme)
            .tint(Color("AccentColor"))
            .background {
                LockShield(lock: lock, enabled: lock.enabled, isLocked: lock.isLocked).frame(width: 0, height: 0)
            }
            .task { if store == nil && !failure { await load() } }
        }
    }

    private var testColorScheme: ColorScheme? {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--uitesting") {
                if ProcessInfo.processInfo.arguments.contains("--test-dark") { return .dark }
                if ProcessInfo.processInfo.arguments.contains("--test-light") { return .light }
            }
        #endif
        return nil
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
                        FileManager.default.fileExists(atPath: directory.path)
                    {
                        try FileManager.default.removeItem(at: directory)
                    }
                }
            #endif
            let loaded = try CollectionStore(directory: directory)
            // Finish cleanup before exposing editors, but never block a valid collection on orphan cleanup.
            do { try await loaded.reconcilePhotos() } catch {
                Logger(subsystem: "pl.jakubbatycki.MojeZegarki", category: "Storage").error(
                    "Asset cleanup failed: \(error.localizedDescription, privacy: .public)")
            }
            #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--uitesting"),
                    ProcessInfo.processInfo.arguments.contains("--test-document-fixture")
                {
                    try await seedDocumentFixture(in: loaded)
                }
            #endif
            #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--uitesting"),
                    ProcessInfo.processInfo.arguments.contains("--test-wear-fixture")
                {
                    var draft = TimepieceDraft()
                    draft.brand = "TestBrand"
                    draft.modelName = "Calendar watch"
                    let watch = try loaded.save(draft)
                    try loaded.logWear(for: watch, date: .now)
                    draft.modelName = "Second watch"
                    _ = try loaded.save(draft)
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
            let imageFixture = ProcessInfo.processInfo.arguments.contains("--test-image-document")
            let bytes =
                imageFixture
                ? UIGraphicsImageRenderer(size: CGSize(width: 400, height: 600)).jpegData(withCompressionQuality: 0.8) {
                    context in
                    UIColor.white.setFill()
                    context.fill(CGRect(x: 0, y: 0, width: 400, height: 600))
                    ("Test invoice" as NSString).draw(at: CGPoint(x: 30, y: 30), withAttributes: nil)
                } : pdf
            let asset = try await store.documentStore.importData(bytes)
            if ProcessInfo.processInfo.arguments.contains("--test-corrupt-document") {
                let url = store.documentStore.root.appendingPathComponent(asset.id.uuidString).appendingPathComponent(
                    asset.filename)
                try Data("corrupt".utf8).write(to: url)
            }
            if ProcessInfo.processInfo.arguments.contains("--test-missing-document") {
                try await store.documentStore.remove(asset.id)
            }
            try store.attachDocument(
                asset, to: watch, name: "Test invoice", kind: .purchase, date: nil, notes: "Private test document")
        }
    #endif
}
