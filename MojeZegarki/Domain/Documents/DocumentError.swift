import Foundation

enum DocumentError: LocalizedError {
    case tooLarge, unsupported, protectedPDF, duplicate, missingFile
    var errorDescription: String? {
        switch self {
        case .tooLarge: String(localized: "A document can be up to 20 MB. Choose a smaller file.")
        case .unsupported: String(localized: "Choose a readable PDF or photo.")
        case .protectedPDF: String(localized: "Password-protected PDFs are not supported. Choose an unlocked copy.")
        case .duplicate: String(localized: "This document is already attached to this watch.")
        case .missingFile: String(localized: "The document file could not be opened.")
        }
    }
}
