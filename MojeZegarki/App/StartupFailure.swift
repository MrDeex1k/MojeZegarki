import Foundation
import OSLog

struct StartupFailure {
    enum Kind { case storageFull, unavailable, other }
    let kind: Kind

    init(error: any Error) {
        let error = error as NSError
        Logger(subsystem: "pl.jakubbatycki.MojeZegarki", category: "Startup").error(
            "Collection initialization failed: \(error, privacy: .private)")
        kind = Self.classify(error)
    }

    private static func classify(_ error: NSError) -> Kind {
        if (error.domain == NSCocoaErrorDomain && error.code == NSFileWriteOutOfSpaceError)
            || (error.domain == NSPOSIXErrorDomain && error.code == Int(ENOSPC))
        {
            return .storageFull
        }
        if error.domain == NSCocoaErrorDomain,
            [NSFileReadNoPermissionError, NSFileWriteNoPermissionError].contains(error.code)
        {
            return .unavailable
        }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError { return classify(underlying) }
        return .other
    }

    var message: LocalizedStringResource {
        switch kind {
        case .storageFull: "Your data has not been reset. Free some storage on your iPhone and try again."
        case .unavailable: "Your data has not been reset. Unlock your iPhone and try again."
        case .other: "Your data has not been reset. Try again. If the problem continues, contact support."
        }
    }
}
