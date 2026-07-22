import Foundation

enum DateRecurrence: String, Codable, CaseIterable, Identifiable, Sendable {
    case oneTime
    case yearly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oneTime:
            return "One time"
        case .yearly:
            return "Yearly"
        }
    }
}
