import Foundation

/// Internal safety classification for check-ins.
/// Raw case labels must not be shown directly in user-facing copy.
enum SafetyState: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case standard
    case elevatedConcern
    case immediateConcern

    var id: String { rawValue }

    /// Prefer this over exposing raw enum labels in UI.
    var isImmediateConcern: Bool {
        self == .immediateConcern
    }

    var isElevatedOrImmediate: Bool {
        switch self {
        case .elevatedConcern, .immediateConcern:
            return true
        case .standard:
            return false
        }
    }

    /// Non-clinical, supportive copy for UI when a concern state is active.
    var supportiveMessage: String {
        switch self {
        case .standard:
            return ""
        case .elevatedConcern:
            return "If things feel heavy, it is okay to pause and reach out to someone you trust."
        case .immediateConcern:
            return "If you are in immediate danger or thinking about harming yourself, contact local emergency services or a crisis line now."
        }
    }
}
