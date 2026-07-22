import Foundation

enum FeedbackResponse: String, Codable, CaseIterable, Identifiable, Sendable {
    case helped
    case noChange
    case madeThingsHarder
    case notRelevant
    case notNow
    case showLessOften
    case doNotUseForThisFeeling

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .helped:
            return "This helped"
        case .noChange:
            return "No change"
        case .madeThingsHarder:
            return "This made things harder"
        case .notRelevant:
            return "Not what I need"
        case .notNow:
            return "Not now"
        case .showLessOften:
            return "Show less often"
        case .doNotUseForThisFeeling:
            return "Do not use for this feeling"
        }
    }

    /// Primary optional responses shown after a recommendation.
    static var primaryResponses: [FeedbackResponse] {
        [.helped, .noChange, .notRelevant, .madeThingsHarder]
    }

    var shouldStopEmotionallyChargedContent: Bool {
        self == .madeThingsHarder
    }
}
