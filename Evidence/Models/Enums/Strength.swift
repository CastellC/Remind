import Foundation

enum Strength: String, Codable, CaseIterable, Identifiable, Sendable {
    case resilient
    case caring
    case capable
    case brave
    case creative
    case disciplined
    case thoughtful
    case dependable
    case adaptable
    case worthyOfCare
    case growing

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .resilient:
            return "Resilient"
        case .caring:
            return "Caring"
        case .capable:
            return "Capable"
        case .brave:
            return "Brave"
        case .creative:
            return "Creative"
        case .disciplined:
            return "Disciplined"
        case .thoughtful:
            return "Thoughtful"
        case .dependable:
            return "Dependable"
        case .adaptable:
            return "Adaptable"
        case .worthyOfCare:
            return "Worthy of care"
        case .growing:
            return "Growing"
        }
    }

    /// Default system tag name used when seeding strength tags.
    var systemTagName: String { displayName }
}
