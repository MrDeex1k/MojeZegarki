import Foundation
import Observation

@MainActor @Observable final class DocumentRoute: Identifiable {
    let id: UUID
    var zoom: CGFloat = 1
    init(id: UUID) { self.id = id }
}
