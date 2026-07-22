import Foundation
import SwiftData

@Model
final class EvidenceEntryTag {
    @Attribute(.unique) var id: UUID
    var evidenceEntryID: UUID
    var evidenceTagID: UUID
    var createdAt: Date
    var syncStatusRaw: String

    var entry: EvidenceEntry?
    var tag: EvidenceTag?

    init(
        id: UUID = UUID(),
        evidenceEntryID: UUID,
        evidenceTagID: UUID,
        createdAt: Date = .now,
        syncStatus: SyncStatus = .localOnly,
        entry: EvidenceEntry? = nil,
        tag: EvidenceTag? = nil
    ) {
        self.id = id
        self.evidenceEntryID = evidenceEntryID
        self.evidenceTagID = evidenceTagID
        self.createdAt = createdAt
        self.syncStatusRaw = syncStatus.rawValue
        self.entry = entry
        self.tag = tag
    }

    convenience init(
        entry: EvidenceEntry,
        tag: EvidenceTag,
        syncStatus: SyncStatus = .localOnly
    ) {
        self.init(
            evidenceEntryID: entry.id,
            evidenceTagID: tag.id,
            syncStatus: syncStatus,
            entry: entry,
            tag: tag
        )
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .localOnly }
        set { syncStatusRaw = newValue.rawValue }
    }
}
