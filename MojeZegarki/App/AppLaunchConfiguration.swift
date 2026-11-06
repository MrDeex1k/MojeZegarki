import Foundation

struct AppLaunchConfiguration {
    private let arguments: Set<String>
    init(arguments: [String] = ProcessInfo.processInfo.arguments) { self.arguments = Set(arguments) }

    var isUITesting: Bool {
        #if DEBUG
            arguments.contains("--uitesting")
        #else
            false
        #endif
    }

    /// Accepts fixture and reset flags only in a Debug UI test launch.
    func has(_ flag: String) -> Bool { isUITesting && arguments.contains(flag) }

    var directory: URL? {
        isUITesting ? FileManager.default.temporaryDirectory.appendingPathComponent("CollectionUITests") : nil
    }
}
