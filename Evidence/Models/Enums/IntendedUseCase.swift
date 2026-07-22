import Foundation

/// Onboarding intended-use selections. Display names match product copy.
enum IntendedUseCase: String, Codable, CaseIterable, Identifiable, Sendable {
    case rememberKindWords
    case rememberAccomplishments
    case manageSelfDoubt
    case groundWhenAnxious
    case revisitLoved
    case rememberSurvived
    case buildSelfCompassion
    case saveAdvice
    case somethingElse

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rememberKindWords:
            return "Remember kind things people have said"
        case .rememberAccomplishments:
            return "Remember what I have accomplished"
        case .manageSelfDoubt:
            return "Manage self-doubt"
        case .groundWhenAnxious:
            return "Ground myself when anxious"
        case .revisitLoved:
            return "Revisit evidence that I am loved"
        case .rememberSurvived:
            return "Remember what I have survived"
        case .buildSelfCompassion:
            return "Build self-compassion"
        case .saveAdvice:
            return "Save advice that helps me"
        case .somethingElse:
            return "Something else"
        }
    }

    /// Maximum number of intended uses selectable during onboarding.
    static let maxSelections = 3
}
