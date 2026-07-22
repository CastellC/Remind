import Foundation

enum ImportMethod: String, Codable, CaseIterable, Identifiable, Sendable {
    case manual
    case photoLibrary
    case guided
    case seed
    case migration

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .manual:
            return "Written"
        case .photoLibrary:
            return "Photo library"
        case .guided:
            return "Guided"
        case .seed:
            return "Sample"
        case .migration:
            return "Migrated"
        }
    }
}
