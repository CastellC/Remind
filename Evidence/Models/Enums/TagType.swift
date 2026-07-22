import Foundation

enum TagType: String, Codable, CaseIterable, Identifiable, Sendable {
    case emotion
    case supportNeed
    case strength
    case lifeArea
    case theme
    case person
    case occasion

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .emotion:
            return "Emotion"
        case .supportNeed:
            return "Support need"
        case .strength:
            return "Strength"
        case .lifeArea:
            return "Life area"
        case .theme:
            return "Theme"
        case .person:
            return "Person"
        case .occasion:
            return "Occasion"
        }
    }
}
