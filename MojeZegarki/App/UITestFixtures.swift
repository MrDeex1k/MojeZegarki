#if DEBUG
    import SwiftData
    import UIKit

    @MainActor struct UITestFixtures {
        let configuration: AppLaunchConfiguration
        let directory: URL

        /// Keep accessibility audits on the app's lock screen, outside the system passcode sheet.
        @MainActor struct CancelledAuthenticator: DeviceAuthenticating {
            func authenticate(reason: String) async throws -> Bool { false }
            func invalidate() {}
        }

        func seed(in store: CollectionStore) async throws {
            if configuration.has("--test-photo-preview-fixture") {
                try await once("photos") { try await photos(in: store) }
            }
            if configuration.has("--test-document-fixture") {
                try await once("documents") { try await document(in: store) }
            }
            if configuration.has("--test-wear-fixture") {
                try await once("wear") {
                    let watch = try fixtureWatch("Calendar watch", in: store)
                    try store.logWear(for: watch, date: .now)
                    if configuration.has("--test-statistics-fixture"),
                        let date = Calendar(identifier: .gregorian).date(byAdding: .day, value: -400, to: .now)
                    {
                        try store.logWear(for: watch, date: date)
                    }
                    _ = try fixtureWatch("Second watch", in: store)
                }
            }
        }

        /// Records completion only after the fixture operation succeeds so a partial setup can be retried.
        private func once(_ name: String, operation: () async throws -> Void) async throws {
            let marker = directory.appendingPathComponent("fixture-\(name)-v1.ready")
            guard !FileManager.default.fileExists(atPath: marker.path) else { return }
            try await operation()
            try Data().write(to: marker, options: [.atomic, .completeFileProtection])
        }

        /// Finds a fixture by its seeded identity so a relaunch can reuse the same record.
        private func existingWatch(_ name: String, in store: CollectionStore) throws -> Timepiece? {
            var query = FetchDescriptor<Timepiece>(
                predicate: #Predicate {
                    $0.brand == "TestBrand" && $0.modelName == name
                })
            query.fetchLimit = 1
            return try store.context.fetch(query).first
        }

        /// Reuses a matching fixture watch or inserts it if seeding has not created it yet.
        private func fixtureWatch(_ name: String, in store: CollectionStore) throws -> Timepiece {
            if let watch = try existingWatch(name, in: store) { return watch }
            var draft = TimepieceDraft()
            draft.brand = "TestBrand"
            draft.modelName = name
            return try store.save(draft)
        }

        private func photoData(size: CGSize) -> Data {
            UIGraphicsImageRenderer(size: size).jpegData(withCompressionQuality: 0.9) { context in
                UIColor.systemTeal.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                UIColor.white.setStroke()
                context.cgContext.setLineWidth(20)
                context.cgContext.stroke(CGRect(origin: .zero, size: size).insetBy(dx: 20, dy: 20))
                ("Photo preview" as NSString).draw(
                    at: CGPoint(x: 60, y: 60),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 60), .foregroundColor: UIColor.white])
            }
        }

        /// Seeds the gallery and wishlist with separate photo assets so either owner can delete its own files.
        private func photos(in store: CollectionStore) async throws {
            if try existingWatch("Photo watch", in: store) == nil {
                var draft = TimepieceDraft()
                draft.brand = "TestBrand"
                draft.modelName = "Photo watch"
                for size in [CGSize(width: 1200, height: 700), CGSize(width: 700, height: 1200)] {
                    draft.photos.append(try await store.photoStore.importPhoto(photoData(size: size)))
                }
                draft.mainPhotoID = draft.photos.first?.id
                _ = try store.save(draft)
            }
            let query = FetchDescriptor<WishlistItem>(
                predicate: #Predicate {
                    $0.brand == "TestBrand" && $0.modelName == "Photo wish"
                })
            if try store.context.fetchCount(query) == 0 {
                var wish = WishlistDraft()
                wish.brand = "TestBrand"
                wish.modelName = "Photo wish"
                // Separate import: each owner can remove its photo independently.
                wish.photo = try await store.photoStore.importPhoto(photoData(size: CGSize(width: 700, height: 1200)))
                _ = try store.saveWish(wish)
            }
            if configuration.has("--test-missing-photo"), let watch = try existingWatch("Photo watch", in: store) {
                for photo in watch.sortedPhotos { try await store.photoStore.remove(photo.id) }
            }
        }

        /// Seeds the requested document variant so the preview tests can cover both successful and failed reads.
        private func document(in store: CollectionStore) async throws {
            let watch = try fixtureWatch("Document watch", in: store)
            guard (watch.documents ?? []).isEmpty else { return }
            let bounds = CGRect(x: 0, y: 0, width: 400, height: 600)
            let bytes: Data
            if configuration.has("--test-image-document") {
                bytes = UIGraphicsImageRenderer(size: bounds.size).jpegData(withCompressionQuality: 0.8) { context in
                    UIColor.white.setFill()
                    context.fill(bounds)
                    ("Test invoice" as NSString).draw(at: CGPoint(x: 30, y: 30), withAttributes: nil)
                }
            } else {
                bytes = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
                    context.beginPage()
                    ("Test invoice / 2026" as NSString).draw(at: CGPoint(x: 30, y: 30), withAttributes: nil)
                }
            }
            let asset = try await store.documentStore.importData(bytes)
            if configuration.has("--test-corrupt-document") {
                let url = store.documentStore.root.appendingPathComponent(asset.id.uuidString).appendingPathComponent(
                    asset.filename)
                try Data("corrupt".utf8).write(to: url, options: [.atomic, .completeFileProtection])
            }
            if configuration.has("--test-missing-document") { try await store.documentStore.remove(asset.id) }
            try store.attachDocument(
                asset, to: watch, name: "Test invoice", kind: .purchase, date: nil,
                notes: configuration.has("--test-long-note")
                    ? String(repeating: "Private invoice note. ", count: 35) : "Private test document")
        }
    }
#endif
