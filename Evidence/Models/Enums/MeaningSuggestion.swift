import Foundation

/// Static suggested answers for “Why might future you need this?”
enum MeaningSuggestion: String, Codable, CaseIterable, Identifiable, Sendable {
    case someoneBelievedInMe
    case iHelpedSomeone
    case iAccomplishedSomethingDifficult
    case iFeltLoved
    case iWasBrave
    case iGotThroughSomethingHard
    case thisRemindsMeWhoIAm
    case thisHelpsGroundMe
    case thisShowsICanLearnAndGrow
    case somethingElse

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .someoneBelievedInMe:
            return "Someone believed in me"
        case .iHelpedSomeone:
            return "I helped someone"
        case .iAccomplishedSomethingDifficult:
            return "I accomplished something difficult"
        case .iFeltLoved:
            return "I felt loved"
        case .iWasBrave:
            return "I was brave"
        case .iGotThroughSomethingHard:
            return "I got through something hard"
        case .thisRemindsMeWhoIAm:
            return "This reminds me who I am"
        case .thisHelpsGroundMe:
            return "This helps ground me"
        case .thisShowsICanLearnAndGrow:
            return "This shows that I can learn and grow"
        case .somethingElse:
            return "Something else"
        }
    }

    /// Prompt copy shown above meaning suggestions in the entry editor.
    static let promptQuestion = "Why might future you need this?"

    /// All suggested answers in product order.
    static var suggestedAnswers: [String] {
        allCases.map(\.displayName)
    }

    /// Whether selecting this suggestion expects free-form custom text.
    var expectsCustomText: Bool {
        self == .somethingElse
    }
}
