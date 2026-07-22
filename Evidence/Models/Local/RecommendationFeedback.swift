import Foundation
import SwiftData

@Model
final class RecommendationFeedback {
    @Attribute(.unique) var id: UUID
    var remoteID: UUID?
    var ownerUserID: UUID?
    var recommendationSessionID: UUID?
    var checkInID: UUID?
    var evidenceEntryID: UUID?
    var guidedContentID: UUID?
    var responseRaw: String
    var createdAt: Date
    var emotionAtTimeRaw: String?
    var supportNeedAtTimeRaw: String?
    var syncStatusRaw: String

    var session: RecommendationSession?

    init(
        id: UUID = UUID(),
        remoteID: UUID? = nil,
        ownerUserID: UUID? = nil,
        recommendationSessionID: UUID? = nil,
        checkInID: UUID? = nil,
        evidenceEntryID: UUID? = nil,
        guidedContentID: UUID? = nil,
        response: FeedbackResponse,
        createdAt: Date = .now,
        emotionAtTime: Emotion? = nil,
        supportNeedAtTime: SupportNeed? = nil,
        syncStatus: SyncStatus = .localOnly,
        session: RecommendationSession? = nil
    ) {
        self.id = id
        self.remoteID = remoteID
        self.ownerUserID = ownerUserID
        self.recommendationSessionID = recommendationSessionID
        self.checkInID = checkInID
        self.evidenceEntryID = evidenceEntryID
        self.guidedContentID = guidedContentID
        self.responseRaw = response.rawValue
        self.createdAt = createdAt
        self.emotionAtTimeRaw = emotionAtTime?.rawValue
        self.supportNeedAtTimeRaw = supportNeedAtTime?.rawValue
        self.syncStatusRaw = syncStatus.rawValue
        self.session = session
    }

    var response: FeedbackResponse {
        get { FeedbackResponse(rawValue: responseRaw) ?? .notNow }
        set { responseRaw = newValue.rawValue }
    }

    var emotionAtTime: Emotion? {
        get {
            guard let emotionAtTimeRaw else { return nil }
            return Emotion(rawValue: emotionAtTimeRaw)
        }
        set { emotionAtTimeRaw = newValue?.rawValue }
    }

    var supportNeedAtTime: SupportNeed? {
        get {
            guard let supportNeedAtTimeRaw else { return nil }
            return SupportNeed(rawValue: supportNeedAtTimeRaw)
        }
        set { supportNeedAtTimeRaw = newValue?.rawValue }
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .localOnly }
        set { syncStatusRaw = newValue.rawValue }
    }
}
