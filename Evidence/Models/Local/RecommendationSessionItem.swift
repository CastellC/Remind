import Foundation
import SwiftData

@Model
final class RecommendationSessionItem {
    @Attribute(.unique) var id: UUID
    var sessionID: UUID
    var evidenceEntryID: UUID?
    var guidedContentID: UUID?
    var sequencePosition: Int
    var score: Double
    var selectionReason: String
    var createdAt: Date

    var session: RecommendationSession?

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        evidenceEntryID: UUID? = nil,
        guidedContentID: UUID? = nil,
        sequencePosition: Int,
        score: Double,
        selectionReason: String,
        createdAt: Date = .now,
        session: RecommendationSession? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.evidenceEntryID = evidenceEntryID
        self.guidedContentID = guidedContentID
        self.sequencePosition = sequencePosition
        self.score = score
        self.selectionReason = selectionReason
        self.createdAt = createdAt
        self.session = session
    }

    convenience init(
        session: RecommendationSession,
        evidenceEntryID: UUID? = nil,
        guidedContentID: UUID? = nil,
        sequencePosition: Int,
        score: Double,
        selectionReason: String
    ) {
        self.init(
            sessionID: session.id,
            evidenceEntryID: evidenceEntryID,
            guidedContentID: guidedContentID,
            sequencePosition: sequencePosition,
            score: score,
            selectionReason: selectionReason,
            session: session
        )
    }

    var isPersonalEvidence: Bool {
        evidenceEntryID != nil
    }

    var isGuidedContent: Bool {
        guidedContentID != nil
    }
}
