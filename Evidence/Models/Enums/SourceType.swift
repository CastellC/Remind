import Foundation

enum SourceType: String, Codable, CaseIterable, Identifiable, Sendable {
    case `self`
    case friend
    case family
    case partner
    case coworker
    case manager
    case teacherOrMentor
    case professional
    case bookOrArticle
    case socialMedia
    case unknown
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .self:
            return "Myself"
        case .friend:
            return "Friend"
        case .family:
            return "Family"
        case .partner:
            return "Partner"
        case .coworker:
            return "Coworker"
        case .manager:
            return "Manager"
        case .teacherOrMentor:
            return "Teacher or mentor"
        case .professional:
            return "Professional"
        case .bookOrArticle:
            return "Book or article"
        case .socialMedia:
            return "Social media"
        case .unknown:
            return "Unknown"
        case .other:
            return "Other"
        }
    }
}
