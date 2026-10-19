import Foundation

struct DocumentDraft: Equatable {
    let name: String
    let kind: DocumentKind
    let date: Date?
    let notes: String
}
