import Foundation
import SwiftData

@Model
final class CheckIn {
    @Attribute(.unique) var id: UUID
    var remoteID: UUID?
    var ownerUserID: UUID?
    var createdAt: Date
    var completedAt: Date?
    var emotionRaw: String
    /// Intensity on a 1…5 scale when provided.
    var intensity: Int?
    var supportNeedRaw: String?
    var optionalNote: String?
    /// When true, `optionalNote` must not be uploaded even if cloud sync is enabled.
    var keepNoteLocalOnly: Bool
    var safetyStateRaw: String
    var recommendationSessionID: UUID?
    var syncStatusRaw: String

    @Relationship(deleteRule: .nullify, inverse: \RecommendationSession.checkIn)
    var recommendationSession: RecommendationSession?

    init(
        id: UUID = UUID(),
        remoteID: UUID? = nil,
        ownerUserID: UUID? = nil,
        createdAt: Date = .now,
        completedAt: Date? = nil,
        emotion: Emotion,
        intensity: Int? = nil,
        supportNeed: SupportNeed? = nil,
        optionalNote: String? = nil,
        keepNoteLocalOnly: Bool = true,
        safetyState: SafetyState = .standard,
        recommendationSessionID: UUID? = nil,
        syncStatus: SyncStatus = .localOnly
    ) {
        self.id = id
        self.remoteID = remoteID
        self.ownerUserID = ownerUserID
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.emotionRaw = emotion.rawValue
        self.intensity = intensity.map { min(5, max(1, $0)) }
        self.supportNeedRaw = supportNeed?.rawValue
        self.optionalNote = optionalNote
        self.keepNoteLocalOnly = keepNoteLocalOnly
        self.safetyStateRaw = safetyState.rawValue
        self.recommendationSessionID = recommendationSessionID
        self.syncStatusRaw = syncStatus.rawValue
    }

    var emotion: Emotion {
        get { Emotion(rawValue: emotionRaw) ?? .notSure }
        set { emotionRaw = newValue.rawValue }
    }

    var supportNeed: SupportNeed? {
        get {
            guard let supportNeedRaw else { return nil }
            return SupportNeed(rawValue: supportNeedRaw)
        }
        set { supportNeedRaw = newValue?.rawValue }
    }

    var safetyState: SafetyState {
        get { SafetyState(rawValue: safetyStateRaw) ?? .standard }
        set { safetyStateRaw = newValue.rawValue }
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .localOnly }
        set { syncStatusRaw = newValue.rawValue }
    }

    var isComplete: Bool {
        completedAt != nil
    }

    /// Note payload safe to upload given privacy settings.
    var noteForUpload: String? {
        guard !keepNoteLocalOnly else { return nil }
        return optionalNote
    }

    func complete(at date: Date = .now) {
        completedAt = date
    }
}

extension CheckIn {
    /// Intensity labels from the product check-in flow (1…5).
    static let intensityLabels: [Int: String] = [
        1: "Present but manageable",
        2: "Uncomfortable",
        3: "Difficult",
        4: "Very difficult",
        5: "Overwhelming"
    ]

    var intensityDisplayName: String? {
        guard let intensity else { return nil }
        return Self.intensityLabels[intensity]
    }
}
