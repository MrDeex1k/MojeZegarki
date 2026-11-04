import Foundation

struct DocumentDraft: Equatable {
    var name: String
    var kind: DocumentKind
    var date: Date?
    var notes: String
}
