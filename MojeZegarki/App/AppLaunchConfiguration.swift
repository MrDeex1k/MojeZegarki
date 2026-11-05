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

    func has(_ flag: String) -> Bool { isUITesting && arguments.contains(flag) }

    var directory: URL? {
        isUITesting ? FileManager.default.temporaryDirectory.appendingPathComponent("CollectionUITests") : nil
    }
}
