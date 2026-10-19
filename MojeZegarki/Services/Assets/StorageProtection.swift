import Foundation

/// Apply the same at-rest protection to existing assets, SQLite and its sidecars.
/// The app entitlement supplies this default for files created later by frameworks.
enum StorageProtection {
    static func prepareDirectory(_ root: URL) throws {
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete])
        try protect(root)
    }

    static func protectExistingFiles(in root: URL) throws {
        try protect(root)
        var enumerationError: (any Error)?
        guard
            let entries = FileManager.default.enumerator(
                at: root, includingPropertiesForKeys: [.isSymbolicLinkKey], options: [],
                errorHandler: { _, error in
                    enumerationError = error
                    return false
                })
        else { throw CollectionError.fileAccess }
        for case let url as URL in entries {
            guard try url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else {
                entries.skipDescendants()
                continue
            }
            try protect(url)
        }
        if let enumerationError { throw enumerationError }
    }

    static func protectDatabaseFiles(in root: URL) throws {
        for name in ["collection.store", "collection.store-wal", "collection.store-shm"] {
            let url = root.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) { try protect(url) }
        }
    }

    private static func protect(_ url: URL) throws {
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
    }
}
