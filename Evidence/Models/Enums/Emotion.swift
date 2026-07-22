import Foundation

enum Emotion: String, Codable, CaseIterable, Identifiable, Sendable {
    case anxious
    case down
    case selfCritical
    case lonely
    case overwhelmed
    case angry
    case ashamed
    case uncertain
    case numb
    case notSure

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anxious:
            return "Anxious"
        case .down:
            return "Down"
        case .selfCritical:
            return "Self-critical"
        case .lonely:
            return "Lonely"
        case .overwhelmed:
            return "Overwhelmed"
        case .angry:
            return "Angry"
        case .ashamed:
            return "Ashamed"
        case .uncertain:
            return "Uncertain"
        case .numb:
            return "Numb"
        case .notSure:
            return "Not sure"
        }
    }

    /// SF Symbol name for accessible choice UI.
    var symbolName: String {
        switch self {
        case .anxious:
            return "cloud.rain"
        case .down:
            return "cloud"
        case .selfCritical:
            return "exclamationmark.bubble"
        case .lonely:
            return "person"
        case .overwhelmed:
            return "waveform.path"
        case .angry:
            return "flame"
        case .ashamed:
            return "eye.slash"
        case .uncertain:
            return "questionmark.circle"
        case .numb:
            return "circle.slash"
        case .notSure:
            return "ellipsis.circle"
        }
    }
}
