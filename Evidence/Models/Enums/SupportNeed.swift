import Foundation

enum SupportNeed: String, Codable, CaseIterable, Identifiable, Sendable {
    case reassurance
    case perspective
    case grounding
    case evidenceOfCapability
    case evidenceOfConnection
    case evidenceOfGrowth
    case oneSmallStep
    case quietReflection

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .reassurance:
            return "Reassurance"
        case .perspective:
            return "Perspective"
        case .grounding:
            return "Grounding"
        case .evidenceOfCapability:
            return "Evidence of capability"
        case .evidenceOfConnection:
            return "Evidence of connection"
        case .evidenceOfGrowth:
            return "Evidence of growth"
        case .oneSmallStep:
            return "One small step"
        case .quietReflection:
            return "Quiet reflection"
        }
    }

    /// SF Symbol name for accessible choice UI.
    var symbolName: String {
        switch self {
        case .reassurance:
            return "hand.raised.fill"
        case .perspective:
            return "binoculars"
        case .grounding:
            return "leaf"
        case .evidenceOfCapability:
            return "checkmark.seal"
        case .evidenceOfConnection:
            return "person.2"
        case .evidenceOfGrowth:
            return "arrow.triangle.2.circlepath"
        case .oneSmallStep:
            return "figure.walk"
        case .quietReflection:
            return "moon.stars"
        }
    }
}
