import Foundation

/// Detects clear, high-confidence safety-related language in free text.
/// Does not diagnose. Conservative phrase matching only.
protocol SafetyLanguageDetecting: Sendable {
    func evaluate(_ text: String) -> SafetyState
}

/// Local deterministic detector using bundled phrase lists.
struct LocalSafetyLanguageDetector: SafetyLanguageDetecting {
    private let content: SafetyContentConfiguration

    init(content: SafetyContentConfiguration = .loadBundledOrEmbedded()) {
        self.content = content
    }

    func evaluate(_ text: String) -> SafetyState {
        let normalized = Self.normalize(text)
        guard !normalized.isEmpty else { return .standard }

        if content.immediateConcernPhrases.contains(where: { normalized.contains($0) }) {
            return .immediateConcern
        }

        // Persecutory / suspicious language → elevated concern (separate UI path).
        // Never treat as immediate concern without clear danger phrases.
        if content.persecutoryPhrases.contains(where: { normalized.contains($0) }) {
            return .elevatedConcern
        }

        if content.elevatedConcernPhrases.contains(where: { normalized.contains($0) }) {
            return .elevatedConcern
        }

        return .standard
    }

    static func normalize(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

/// Bundled safety phrase lists and support copy. Never logged as private user content.
struct SafetyContentConfiguration: Codable, Equatable, Sendable {
    var immediateConcernPhrases: [String]
    var elevatedConcernPhrases: [String]
    var persecutoryPhrases: [String]
    var immediateSupportTitle: String
    var immediateSupportBody: String
    var elevatedSupportTitle: String
    var elevatedSupportBody: String
    var disclaimer: String

    static func loadBundledOrEmbedded() -> SafetyContentConfiguration {
        if let url = Bundle.main.url(forResource: "SafetyContent", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(SafetyContentConfiguration.self, from: data) {
            return decoded
        }
        return .embedded
    }

    /// Conservative embedded fallback when the bundle resource is unavailable.
    static let embedded = SafetyContentConfiguration(
        immediateConcernPhrases: [
            "want to die",
            "wanna die",
            "kill myself",
            "killing myself",
            "end my life",
            "ending my life",
            "suicide",
            "suicidal",
            "take my own life",
            "hurt myself",
            "harm myself",
            "cut myself",
            "self-harm",
            "self harm",
            "going to hurt someone",
            "going to kill someone",
            "kill them",
            "hurt them tonight",
            "not safe right now",
            "i am not safe",
            "i'm not safe",
            "about to hurt myself",
            "plan to die",
            "planning to die"
        ],
        elevatedConcernPhrases: [
            "don't want to be here",
            "do not want to be here",
            "wish i wasn't here",
            "wish i wasnt here",
            "better off without me",
            "can't go on",
            "cannot go on",
            "no reason to live"
        ],
        persecutoryPhrases: [
            "they are watching me",
            "they're watching me",
            "being watched",
            "being followed",
            "they are following me",
            "they're following me",
            "someone is tracking me",
            "they are tracking me",
            "they're tracking me",
            "being poisoned",
            "they poisoned",
            "conspiring against me",
            "plotting against me",
            "out to get me",
            "bugged my",
            "implanted a",
            "mind control"
        ],
        immediateSupportTitle: "You may need support right now",
        immediateSupportBody: "Evidence may not be enough for what you are going through. If you are in immediate danger, contact local emergency services. Consider reaching out to someone you trust or a qualified professional.",
        elevatedSupportTitle: "It may help to slow down",
        elevatedSupportBody: "That sounds frightening. It may help to slow down and separate what you directly observed from what you fear may be happening.",
        disclaimer: "Evidence supports personal reflection and grounding. It does not diagnose conditions, provide medical treatment, or replace professional care."
    )
}

/// Always-standard detector for previews that must not trip safety UI.
struct PassthroughSafetyLanguageDetector: SafetyLanguageDetecting {
    func evaluate(_ text: String) -> SafetyState { .standard }
}
