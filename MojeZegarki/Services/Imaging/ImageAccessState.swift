import Foundation
import Observation

@MainActor @Observable final class ImageAccessState {
    private(set) var revision = UUID()

    func retryLoads() { revision = UUID() }
}
