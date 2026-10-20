import Foundation

struct AssetReconciliationError: Error {
    let failures: [any Error]
}
