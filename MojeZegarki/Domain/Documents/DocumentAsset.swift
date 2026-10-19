import Foundation

struct DocumentAsset: Identifiable, Sendable {
    let id: UUID
    let filename: String
    let contentType: String
    let fileSize: Int
    let contentHash: String
}
