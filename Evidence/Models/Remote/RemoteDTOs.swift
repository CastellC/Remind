import Foundation

// MARK: - Shared remote helpers

enum RemoteDTOCoding {
    static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func decodeDate(from string: String?) -> Date? {
        guard let string else { return nil }
        return iso8601Fractional.date(from: string) ?? iso8601.date(from: string)
    }
}

/// Flexible date decoding for Supabase `timestamptz` values.
struct RemoteDate: Codable, Hashable, Sendable {
    var value: Date

    init(_ value: Date) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let date = try? container.decode(Date.self) {
            value = date
            return
        }
        let string = try container.decode(String.self)
        guard let date = RemoteDTOCoding.decodeDate(from: string) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized date string: \(string)"
            )
        }
        value = date
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(RemoteDTOCoding.iso8601Fractional.string(from: value))
    }
}

// MARK: - profiles

struct RemoteProfileDTO: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var userID: UUID
    var displayName: String?
    var selectedUseCases: [String]
    var appLockEnabled: Bool
    var notificationPreviewMode: String
    var hasSeenSafetyInformation: Bool
    var cloudSyncEnabled: Bool
    var keepCheckInNotesLocalOnly: Bool
    var onboardingCompletedAt: RemoteDate?
    var lastSuccessfulSyncAt: RemoteDate?
    var createdAt: RemoteDate
    var updatedAt: RemoteDate

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case displayName = "display_name"
        case selectedUseCases = "selected_use_cases"
        case appLockEnabled = "app_lock_enabled"
        case notificationPreviewMode = "notification_preview_mode"
        case hasSeenSafetyInformation = "has_seen_safety_information"
        case cloudSyncEnabled = "cloud_sync_enabled"
        case keepCheckInNotesLocalOnly = "keep_check_in_notes_local_only"
        case onboardingCompletedAt = "onboarding_completed_at"
        case lastSuccessfulSyncAt = "last_successful_sync_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - evidence_entries

struct RemoteEvidenceEntryDTO: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var userID: UUID
    var title: String
    var bodyText: String?
    var entryType: String
    var sourceType: String
    var sourceName: String?
    var sourceContext: String?
    var originalURL: String?
    var occurredAt: RemoteDate?
    var meaningfulDate: RemoteDate?
    var isFavorite: Bool
    var isArchived: Bool
    var isSensitive: Bool
    var excludeFromCheckIns: Bool
    var excludeFromNotifications: Bool
    var userAuthored: Bool
    var importMethod: String
    var meaningPromptAnswer: String
    var remoteMediaPath: String?
    var accessibilityDescription: String?
    var pendingDeletion: Bool
    var deletedAt: RemoteDate?
    var createdAt: RemoteDate
    var updatedAt: RemoteDate

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case title
        case bodyText = "body_text"
        case entryType = "entry_type"
        case sourceType = "source_type"
        case sourceName = "source_name"
        case sourceContext = "source_context"
        case originalURL = "original_url"
        case occurredAt = "occurred_at"
        case meaningfulDate = "meaningful_date"
        case isFavorite = "is_favorite"
        case isArchived = "is_archived"
        case isSensitive = "is_sensitive"
        case excludeFromCheckIns = "exclude_from_check_ins"
        case excludeFromNotifications = "exclude_from_notifications"
        case userAuthored = "user_authored"
        case importMethod = "import_method"
        case meaningPromptAnswer = "meaning_prompt_answer"
        case remoteMediaPath = "remote_media_path"
        case accessibilityDescription = "accessibility_description"
        case pendingDeletion = "pending_deletion"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - evidence_tags

struct RemoteEvidenceTagDTO: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var userID: UUID
    var name: String
    var tagType: String
    var origin: String
    var isSystemTag: Bool
    var createdAt: RemoteDate
    var updatedAt: RemoteDate

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case name
        case tagType = "tag_type"
        case origin
        case isSystemTag = "is_system_tag"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - evidence_entry_tags

struct RemoteEvidenceEntryTagDTO: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var userID: UUID
    var evidenceEntryID: UUID
    var evidenceTagID: UUID
    var createdAt: RemoteDate

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case evidenceEntryID = "evidence_entry_id"
        case evidenceTagID = "evidence_tag_id"
        case createdAt = "created_at"
    }
}

// MARK: - categories

struct RemoteCategoryDTO: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var userID: UUID
    var name: String
    var iconName: String?
    var sortOrder: Int
    var createdAt: RemoteDate
    var updatedAt: RemoteDate

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case name
        case iconName = "icon_name"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - evidence_entry_categories

struct RemoteEvidenceEntryCategoryDTO: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var userID: UUID
    var evidenceEntryID: UUID
    var categoryID: UUID
    var createdAt: RemoteDate

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case evidenceEntryID = "evidence_entry_id"
        case categoryID = "category_id"
        case createdAt = "created_at"
    }
}

// MARK: - check_ins

struct RemoteCheckInDTO: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var userID: UUID
    var emotion: String
    var intensity: Int?
    var supportNeed: String?
    var optionalNote: String?
    var safetyState: String
    var recommendationSessionID: UUID?
    var completedAt: RemoteDate?
    var createdAt: RemoteDate
    var updatedAt: RemoteDate

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case emotion
        case intensity
        case supportNeed = "support_need"
        case optionalNote = "optional_note"
        case safetyState = "safety_state"
        case recommendationSessionID = "recommendation_session_id"
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - recommendation_sessions

struct RemoteRecommendationSessionDTO: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var userID: UUID
    var checkInID: UUID
    var currentIndex: Int
    var completedAt: RemoteDate?
    var createdAt: RemoteDate
    var updatedAt: RemoteDate

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case checkInID = "check_in_id"
        case currentIndex = "current_index"
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - recommendation_session_items

struct RemoteRecommendationSessionItemDTO: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var userID: UUID
    var sessionID: UUID
    var evidenceEntryID: UUID?
    var guidedContentID: UUID?
    var sequencePosition: Int
    var score: Double
    var selectionReason: String
    var createdAt: RemoteDate

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case sessionID = "session_id"
        case evidenceEntryID = "evidence_entry_id"
        case guidedContentID = "guided_content_id"
        case sequencePosition = "sequence_position"
        case score
        case selectionReason = "selection_reason"
        case createdAt = "created_at"
    }
}

// MARK: - recommendation_feedback

struct RemoteRecommendationFeedbackDTO: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var userID: UUID
    var recommendationSessionID: UUID?
    var checkInID: UUID?
    var evidenceEntryID: UUID?
    var guidedContentID: UUID?
    var response: String
    var emotionAtTime: String?
    var supportNeedAtTime: String?
    var createdAt: RemoteDate

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case recommendationSessionID = "recommendation_session_id"
        case checkInID = "check_in_id"
        case evidenceEntryID = "evidence_entry_id"
        case guidedContentID = "guided_content_id"
        case response
        case emotionAtTime = "emotion_at_time"
        case supportNeedAtTime = "support_need_at_time"
        case createdAt = "created_at"
    }
}

// MARK: - reminder_preferences

struct RemoteReminderPreferenceDTO: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var userID: UUID
    var isEnabled: Bool
    var selectedWeekdays: [Int]
    var deliveryHour: Int
    var deliveryMinute: Int
    var frequency: String
    var allowedCategoryIDs: [UUID]
    var genericPreviewOnly: Bool
    var lastScheduledAt: RemoteDate?
    var createdAt: RemoteDate
    var updatedAt: RemoteDate

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case isEnabled = "is_enabled"
        case selectedWeekdays = "selected_weekdays"
        case deliveryHour = "delivery_hour"
        case deliveryMinute = "delivery_minute"
        case frequency
        case allowedCategoryIDs = "allowed_category_ids"
        case genericPreviewOnly = "generic_preview_only"
        case lastScheduledAt = "last_scheduled_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - meaningful_date_reminders

struct RemoteMeaningfulDateReminderDTO: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var userID: UUID
    var evidenceEntryID: UUID
    var date: RemoteDate
    var recurrence: String
    var enabled: Bool
    var label: String?
    var reminderHour: Int
    var reminderMinute: Int
    var createdAt: RemoteDate
    var updatedAt: RemoteDate

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case evidenceEntryID = "evidence_entry_id"
        case date
        case recurrence
        case enabled
        case label
        case reminderHour = "reminder_hour"
        case reminderMinute = "reminder_minute"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Mapping helpers (local ↔ remote)

extension RemoteProfileDTO {
    init(profile: AppProfile, userID: UUID) {
        self.id = profile.id
        self.userID = userID
        self.displayName = profile.displayName
        self.selectedUseCases = profile.selectedUseCases.map(\.rawValue)
        self.appLockEnabled = profile.appLockEnabled
        self.notificationPreviewMode = profile.notificationPreviewMode.rawValue
        self.hasSeenSafetyInformation = profile.hasSeenSafetyInformation
        self.cloudSyncEnabled = profile.cloudSyncEnabled
        self.keepCheckInNotesLocalOnly = profile.keepCheckInNotesLocalOnly
        self.onboardingCompletedAt = profile.onboardingCompletedAt.map(RemoteDate.init)
        self.lastSuccessfulSyncAt = profile.lastSuccessfulSyncAt.map(RemoteDate.init)
        self.createdAt = RemoteDate(profile.createdAt)
        self.updatedAt = RemoteDate(profile.updatedAt)
    }
}

extension RemoteEvidenceEntryDTO {
    init(entry: EvidenceEntry, userID: UUID) {
        self.id = entry.remoteID ?? entry.id
        self.userID = userID
        self.title = entry.title
        self.bodyText = entry.bodyText
        self.entryType = entry.entryType.rawValue
        self.sourceType = entry.sourceType.rawValue
        self.sourceName = entry.sourceName
        self.sourceContext = entry.sourceContext
        self.originalURL = entry.originalURLString
        self.occurredAt = entry.occurredAt.map(RemoteDate.init)
        self.meaningfulDate = entry.meaningfulDate.map(RemoteDate.init)
        self.isFavorite = entry.isFavorite
        self.isArchived = entry.isArchived
        self.isSensitive = entry.isSensitive
        self.excludeFromCheckIns = entry.excludeFromCheckIns
        self.excludeFromNotifications = entry.excludeFromNotifications
        self.userAuthored = entry.userAuthored
        self.importMethod = entry.importMethod.rawValue
        self.meaningPromptAnswer = entry.meaningPromptAnswer
        self.remoteMediaPath = entry.remoteMediaPath
        self.accessibilityDescription = entry.accessibilityDescription
        self.pendingDeletion = entry.pendingDeletion
        self.deletedAt = entry.deletedAt.map(RemoteDate.init)
        self.createdAt = RemoteDate(entry.createdAt)
        self.updatedAt = RemoteDate(entry.updatedAt)
    }
}

extension EvidenceEntry {
    /// Applies remote fields onto an existing local entry without overwriting local-only image paths.
    func applyRemoteFields(from dto: RemoteEvidenceEntryDTO) {
        remoteID = dto.id
        ownerUserID = dto.userID
        title = dto.title
        bodyText = dto.bodyText
        entryType = EntryType(rawValue: dto.entryType) ?? entryType
        sourceType = SourceType(rawValue: dto.sourceType) ?? sourceType
        sourceName = dto.sourceName
        sourceContext = dto.sourceContext
        originalURLString = dto.originalURL
        occurredAt = dto.occurredAt?.value
        meaningfulDate = dto.meaningfulDate?.value
        isFavorite = dto.isFavorite
        isArchived = dto.isArchived
        isSensitive = dto.isSensitive
        excludeFromCheckIns = dto.excludeFromCheckIns
        excludeFromNotifications = dto.excludeFromNotifications
        userAuthored = dto.userAuthored
        importMethod = ImportMethod(rawValue: dto.importMethod) ?? importMethod
        meaningPromptAnswer = dto.meaningPromptAnswer
        remoteMediaPath = dto.remoteMediaPath
        accessibilityDescription = dto.accessibilityDescription
        pendingDeletion = dto.pendingDeletion
        deletedAt = dto.deletedAt?.value
        serverUpdatedAt = dto.updatedAt.value
        createdAt = dto.createdAt.value
        updatedAt = dto.updatedAt.value
        syncStatus = .synced
        syncErrorMessage = nil
    }

    static func fromRemote(_ dto: RemoteEvidenceEntryDTO) -> EvidenceEntry {
        EvidenceEntry(
            id: dto.id,
            remoteID: dto.id,
            ownerUserID: dto.userID,
            title: dto.title,
            bodyText: dto.bodyText,
            entryType: EntryType(rawValue: dto.entryType) ?? .text,
            sourceType: SourceType(rawValue: dto.sourceType) ?? .unknown,
            sourceName: dto.sourceName,
            sourceContext: dto.sourceContext,
            originalURLString: dto.originalURL,
            createdAt: dto.createdAt.value,
            updatedAt: dto.updatedAt.value,
            occurredAt: dto.occurredAt?.value,
            meaningfulDate: dto.meaningfulDate?.value,
            isFavorite: dto.isFavorite,
            isArchived: dto.isArchived,
            isSensitive: dto.isSensitive,
            excludeFromCheckIns: dto.excludeFromCheckIns,
            excludeFromNotifications: dto.excludeFromNotifications,
            userAuthored: dto.userAuthored,
            importMethod: ImportMethod(rawValue: dto.importMethod) ?? .migration,
            meaningPromptAnswer: dto.meaningPromptAnswer,
            remoteMediaPath: dto.remoteMediaPath,
            accessibilityDescription: dto.accessibilityDescription,
            syncStatus: .synced,
            pendingDeletion: dto.pendingDeletion,
            serverUpdatedAt: dto.updatedAt.value,
            deletedAt: dto.deletedAt?.value
        )
    }
}
