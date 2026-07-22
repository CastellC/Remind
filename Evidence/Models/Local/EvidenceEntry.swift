import Foundation
import SwiftData

@Model
final class EvidenceEntry {
    @Attribute(.unique) var id: UUID
    var remoteID: UUID?
    var ownerUserID: UUID?
    var title: String
    var bodyText: String?
    var entryTypeRaw: String
    var sourceTypeRaw: String
    var sourceName: String?
    var sourceContext: String?
    var originalURLString: String?
    var createdAt: Date
    var updatedAt: Date
    var occurredAt: Date?
    var meaningfulDate: Date?
    var isFavorite: Bool
    var isArchived: Bool
    var isSensitive: Bool
    var excludeFromCheckIns: Bool
    var excludeFromNotifications: Bool
    var userAuthored: Bool
    var importMethodRaw: String
    /// Required conceptually for personal entries — editor must enforce non-empty before save.
    var meaningPromptAnswer: String
    var localImageFileName: String?
    var remoteMediaPath: String?
    var accessibilityDescription: String?
    var syncStatusRaw: String
    var syncErrorMessage: String?
    var pendingDeletion: Bool
    var serverUpdatedAt: Date?
    var deletedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \EvidenceEntryTag.entry)
    var entryTags: [EvidenceEntryTag] = []

    @Relationship(deleteRule: .cascade, inverse: \EvidenceEntryCategory.entry)
    var entryCategories: [EvidenceEntryCategory] = []

    @Relationship(deleteRule: .cascade, inverse: \MeaningfulDateReminder.entry)
    var meaningfulDateReminders: [MeaningfulDateReminder] = []

    init(
        id: UUID = UUID(),
        remoteID: UUID? = nil,
        ownerUserID: UUID? = nil,
        title: String,
        bodyText: String? = nil,
        entryType: EntryType = .text,
        sourceType: SourceType = .self,
        sourceName: String? = nil,
        sourceContext: String? = nil,
        originalURLString: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        occurredAt: Date? = nil,
        meaningfulDate: Date? = nil,
        isFavorite: Bool = false,
        isArchived: Bool = false,
        isSensitive: Bool = false,
        excludeFromCheckIns: Bool = false,
        excludeFromNotifications: Bool = false,
        userAuthored: Bool = true,
        importMethod: ImportMethod = .manual,
        meaningPromptAnswer: String,
        localImageFileName: String? = nil,
        remoteMediaPath: String? = nil,
        accessibilityDescription: String? = nil,
        syncStatus: SyncStatus = .localOnly,
        syncErrorMessage: String? = nil,
        pendingDeletion: Bool = false,
        serverUpdatedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.remoteID = remoteID
        self.ownerUserID = ownerUserID
        self.title = title
        self.bodyText = bodyText
        self.entryTypeRaw = entryType.rawValue
        self.sourceTypeRaw = sourceType.rawValue
        self.sourceName = sourceName
        self.sourceContext = sourceContext
        self.originalURLString = originalURLString
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.occurredAt = occurredAt
        self.meaningfulDate = meaningfulDate
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.isSensitive = isSensitive
        self.excludeFromCheckIns = excludeFromCheckIns
        self.excludeFromNotifications = excludeFromNotifications
        self.userAuthored = userAuthored
        self.importMethodRaw = importMethod.rawValue
        self.meaningPromptAnswer = meaningPromptAnswer
        self.localImageFileName = localImageFileName
        self.remoteMediaPath = remoteMediaPath
        self.accessibilityDescription = accessibilityDescription
        self.syncStatusRaw = syncStatus.rawValue
        self.syncErrorMessage = syncErrorMessage
        self.pendingDeletion = pendingDeletion
        self.serverUpdatedAt = serverUpdatedAt
        self.deletedAt = deletedAt
    }

    var entryType: EntryType {
        get { EntryType(rawValue: entryTypeRaw) ?? .text }
        set { entryTypeRaw = newValue.rawValue }
    }

    var sourceType: SourceType {
        get { SourceType(rawValue: sourceTypeRaw) ?? .unknown }
        set { sourceTypeRaw = newValue.rawValue }
    }

    var importMethod: ImportMethod {
        get { ImportMethod(rawValue: importMethodRaw) ?? .manual }
        set { importMethodRaw = newValue.rawValue }
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .localOnly }
        set { syncStatusRaw = newValue.rawValue }
    }

    var isPersonalEntry: Bool {
        userAuthored && !entryType.isSystemContent
    }

    var hasRequiredMeaningAnswer: Bool {
        !meaningPromptAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isEligibleForCheckIn: Bool {
        !isArchived && !pendingDeletion && deletedAt == nil && !excludeFromCheckIns
    }

    var isEligibleForNotification: Bool {
        !isArchived
            && !pendingDeletion
            && deletedAt == nil
            && !excludeFromNotifications
            && !isSensitive
    }

    var tags: [EvidenceTag] {
        entryTags.compactMap(\.tag)
    }

    var categories: [CategoryModel] {
        entryCategories.compactMap(\.category)
    }

    func touch(_ date: Date = .now) {
        updatedAt = date
    }

    func markPendingUpload() {
        syncStatus = .pendingUpload
        syncErrorMessage = nil
        touch()
    }

    func markSynced(remoteID: UUID? = nil, serverUpdatedAt: Date = .now) {
        if let remoteID {
            self.remoteID = remoteID
        }
        self.serverUpdatedAt = serverUpdatedAt
        syncStatus = .synced
        syncErrorMessage = nil
        pendingDeletion = false
        touch()
    }

    func markFailed(message: String) {
        syncStatus = .failed
        syncErrorMessage = message
        touch()
    }
}
