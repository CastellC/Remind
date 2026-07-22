import Foundation
import SwiftData

@Model
final class EvidenceTag {
    @Attribute(.unique) var id: UUID
    var remoteID: UUID?
    var ownerUserID: UUID?
    var name: String
    var tagTypeRaw: String
    var originRaw: String
    var createdAt: Date
    var updatedAt: Date
    var isSystemTag: Bool
    var syncStatusRaw: String

    @Relationship(deleteRule: .cascade, inverse: \EvidenceEntryTag.tag)
    var entryLinks: [EvidenceEntryTag] = []

    init(
        id: UUID = UUID(),
        remoteID: UUID? = nil,
        ownerUserID: UUID? = nil,
        name: String,
        tagType: TagType,
        origin: TagOrigin = .user,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isSystemTag: Bool = false,
        syncStatus: SyncStatus = .localOnly
    ) {
        self.id = id
        self.remoteID = remoteID
        self.ownerUserID = ownerUserID
        self.name = name
        self.tagTypeRaw = tagType.rawValue
        self.originRaw = origin.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSystemTag = isSystemTag
        self.syncStatusRaw = syncStatus.rawValue
    }

    var tagType: TagType {
        get { TagType(rawValue: tagTypeRaw) ?? .theme }
        set { tagTypeRaw = newValue.rawValue }
    }

    var origin: TagOrigin {
        get { TagOrigin(rawValue: originRaw) ?? .user }
        set { originRaw = newValue.rawValue }
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .localOnly }
        set { syncStatusRaw = newValue.rawValue }
    }

    var displayName: String { name }

    func touch(_ date: Date = .now) {
        updatedAt = date
    }

    /// Creates a system strength tag from a `Strength` enum case.
    static func systemStrength(_ strength: Strength, ownerUserID: UUID? = nil) -> EvidenceTag {
        EvidenceTag(
            ownerUserID: ownerUserID,
            name: strength.systemTagName,
            tagType: .strength,
            origin: .system,
            isSystemTag: true,
            syncStatus: .localOnly
        )
    }

    static func systemEmotion(_ emotion: Emotion, ownerUserID: UUID? = nil) -> EvidenceTag {
        EvidenceTag(
            ownerUserID: ownerUserID,
            name: emotion.displayName,
            tagType: .emotion,
            origin: .system,
            isSystemTag: true,
            syncStatus: .localOnly
        )
    }

    static func systemSupportNeed(_ need: SupportNeed, ownerUserID: UUID? = nil) -> EvidenceTag {
        EvidenceTag(
            ownerUserID: ownerUserID,
            name: need.displayName,
            tagType: .supportNeed,
            origin: .system,
            isSystemTag: true,
            syncStatus: .localOnly
        )
    }
}
