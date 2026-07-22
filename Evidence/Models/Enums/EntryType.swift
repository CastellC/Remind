import Foundation

enum EntryType: String, Codable, CaseIterable, Identifiable, Sendable {
    case text
    case image
    case guidedReminder
    case groundingTechnique
    case accomplishment
    case meaningfulMemory

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text:
            return "Text"
        case .image:
            return "Image"
        case .guidedReminder:
            return "Guided reminder"
        case .groundingTechnique:
            return "Grounding technique"
        case .accomplishment:
            return "Accomplishment"
        case .meaningfulMemory:
            return "Meaningful memory"
        }
    }

    /// Whether this entry type represents system-authored guided content.
    var isSystemContent: Bool {
        switch self {
        case .guidedReminder, .groundingTechnique:
            return true
        case .text, .image, .accomplishment, .meaningfulMemory:
            return false
        }
    }
}
