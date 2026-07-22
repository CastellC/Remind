import Foundation

enum GuidedContentType: String, Codable, CaseIterable, Identifiable, Sendable {
    case groundedAffirmation
    case groundingExercise
    case reflectionPrompt
    case manageableAction

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .groundedAffirmation:
            return "Grounded affirmation"
        case .groundingExercise:
            return "Grounding exercise"
        case .reflectionPrompt:
            return "Reflection prompt"
        case .manageableAction:
            return "Manageable action"
        }
    }

    /// User-facing label distinguishing system content from personal evidence.
    var systemContentLabel: String {
        "Guided reminder"
    }
}
