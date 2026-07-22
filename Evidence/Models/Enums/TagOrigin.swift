import Foundation

enum TagOrigin: String, Codable, CaseIterable, Identifiable, Sendable {
    case user
    case system
    case futureModelSuggested
    case futureModelConfirmed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .user:
            return "You"
        case .system:
            return "System"
        case .futureModelSuggested:
            return "Suggested"
        case .futureModelConfirmed:
            return "Confirmed suggestion"
        }
    }

    /// Origins permitted in the MVP.
    static var mvpCases: [TagOrigin] { [.user, .system] }

    var isAllowedInMVP: Bool {
        Self.mvpCases.contains(self)
    }
}
