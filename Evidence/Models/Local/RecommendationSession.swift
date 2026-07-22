import Foundation
import SwiftData

@Model
final class RecommendationSession {
    @Attribute(.unique) var id: UUID
    var remoteID: UUID?
    var ownerUserID: UUID?
    var checkInID: UUID
    var createdAt: Date
    var completedAt: Date?
    var currentIndex: Int
    var syncStatusRaw: String

    var checkIn: CheckIn?

    @Relationship(deleteRule: .cascade, inverse: \RecommendationSessionItem.session)
    var items: [RecommendationSessionItem] = []

    @Relationship(deleteRule: .nullify, inverse: \RecommendationFeedback.session)
    var feedback: [RecommendationFeedback] = []

    init(
        id: UUID = UUID(),
        remoteID: UUID? = nil,
        ownerUserID: UUID? = nil,
        checkInID: UUID,
        createdAt: Date = .now,
        completedAt: Date? = nil,
        currentIndex: Int = 0,
        syncStatus: SyncStatus = .localOnly,
        checkIn: CheckIn? = nil
    ) {
        self.id = id
        self.remoteID = remoteID
        self.ownerUserID = ownerUserID
        self.checkInID = checkInID
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.currentIndex = currentIndex
        self.syncStatusRaw = syncStatus.rawValue
        self.checkIn = checkIn
    }

    convenience init(checkIn: CheckIn, syncStatus: SyncStatus = .localOnly) {
        self.init(
            ownerUserID: checkIn.ownerUserID,
            checkInID: checkIn.id,
            syncStatus: syncStatus,
            checkIn: checkIn
        )
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .localOnly }
        set { syncStatusRaw = newValue.rawValue }
    }

    var isComplete: Bool {
        completedAt != nil
    }

    var sortedItems: [RecommendationSessionItem] {
        items.sorted { $0.sequencePosition < $1.sequencePosition }
    }

    var currentItem: RecommendationSessionItem? {
        let sorted = sortedItems
        guard currentIndex >= 0, currentIndex < sorted.count else { return nil }
        return sorted[currentIndex]
    }

    func advance() {
        let next = currentIndex + 1
        if next < items.count {
            currentIndex = next
        } else {
            completedAt = .now
        }
    }

    func complete(at date: Date = .now) {
        completedAt = date
    }
}
