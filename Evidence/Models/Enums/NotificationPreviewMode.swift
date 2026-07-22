import Foundation

enum NotificationPreviewMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case generic
    case titleOnly
    case fullContent

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .generic:
            return "Generic"
        case .titleOnly:
            return "Title only"
        case .fullContent:
            return "Full content"
        }
    }

    var detailExplanation: String {
        switch self {
        case .generic:
            return "Notifications show a private, generic message."
        case .titleOnly:
            return "Notifications may show the entry title. Others nearby might see it."
        case .fullContent:
            return "Notifications may show entry content. Others nearby might see it."
        }
    }

    static let `default`: NotificationPreviewMode = .generic
}
