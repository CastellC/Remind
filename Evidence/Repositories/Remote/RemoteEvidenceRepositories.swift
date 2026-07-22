import Foundation

#if canImport(Supabase)
import Supabase
#endif

/// Errors from remote repository operations.
enum RemoteRepositoryError: Error, LocalizedError, Sendable {
    case notConfigured
    case notAuthenticated
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Cloud sync is not configured."
        case .notAuthenticated:
            return "Sign in to use cloud sync."
        case .requestFailed(let message):
            return message
        }
    }
}

/// Abstraction over a configured Supabase-like client for remote CRUD.
protocol RemoteDatabaseClienting: Sendable {
    func select<T: Decodable & Sendable>(table: String, since updatedAt: Date?) async throws -> [T]
    func upsert<T: Encodable & Sendable>(_ row: T, table: String) async throws
    func delete(table: String, id: UUID) async throws
}

#if canImport(Supabase)
struct SupabaseDatabaseClient: RemoteDatabaseClienting {
    let client: SupabaseClient

    func select<T: Decodable & Sendable>(table: String, since updatedAt: Date?) async throws -> [T] {
        var query = client.from(table).select()
        if let updatedAt {
            let formatted = RemoteDTOCoding.iso8601Fractional.string(from: updatedAt)
            query = query.gte("updated_at", value: formatted)
        }
        return try await query.execute().value
    }

    func upsert<T: Encodable & Sendable>(_ row: T, table: String) async throws {
        try await client.from(table).upsert(row).execute()
    }

    func delete(table: String, id: UUID) async throws {
        try await client.from(table).delete().eq("id", value: id.uuidString).execute()
    }
}
#endif

/// In-memory remote client for tests and offline development.
actor InMemoryRemoteDatabaseClient: RemoteDatabaseClienting {
    private var store: [String: [UUID: Data]] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func select<T: Decodable & Sendable>(table: String, since updatedAt: Date?) async throws -> [T] {
        let rows = store[table]?.values ?? []
        return try rows.compactMap { try decoder.decode(T.self, from: $0) }
    }

    func upsert<T: Encodable & Sendable>(_ row: T, table: String) async throws {
        let data = try encoder.encode(row)
        // Best-effort id extraction via JSON dictionary.
        if let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let idString = object["id"] as? String,
           let id = UUID(uuidString: idString) {
            var tableStore = store[table] ?? [:]
            tableStore[id] = data
            store[table] = tableStore
        }
    }

    func delete(table: String, id: UUID) async throws {
        store[table]?[id] = nil
    }
}

// MARK: - Remote repository facades

/// Supabase-backed remote repositories. Methods compile and work when a client is configured.
struct RemoteEvidenceRepositories: Sendable {
    var client: any RemoteDatabaseClienting
    var userID: UUID?

    // Tables
    private let profiles = "profiles"
    private let entries = "evidence_entries"
    private let tags = "evidence_tags"
    private let categories = "categories"
    private let checkIns = "check_ins"
    private let feedback = "recommendation_feedback"
    private let reminders = "reminder_preferences"
    private let meaningfulDates = "meaningful_date_reminders"

    private func requireUserID() throws -> UUID {
        guard let userID else { throw RemoteRepositoryError.notAuthenticated }
        return userID
    }

    // MARK: Entries

    func fetchEntries(since: Date? = nil) async throws -> [RemoteEvidenceEntryDTO] {
        try await client.select(table: entries, since: since)
    }

    func upsertEntry(_ entry: EvidenceEntry) async throws {
        let userID = try requireUserID()
        let dto = RemoteEvidenceEntryDTO(entry: entry, userID: userID)
        try await client.upsert(dto, table: entries)
    }

    func deleteEntry(id: UUID) async throws {
        _ = try requireUserID()
        try await client.delete(table: entries, id: id)
    }

    // MARK: Tags

    func fetchTags(since: Date? = nil) async throws -> [RemoteEvidenceTagDTO] {
        try await client.select(table: tags, since: since)
    }

    func upsertTag(_ tag: EvidenceTag) async throws {
        let userID = try requireUserID()
        let dto = RemoteEvidenceTagDTO(
            id: tag.remoteID ?? tag.id,
            userID: userID,
            name: tag.name,
            tagType: tag.tagType.rawValue,
            origin: tag.origin.rawValue,
            isSystemTag: tag.isSystemTag,
            createdAt: RemoteDate(tag.createdAt),
            updatedAt: RemoteDate(tag.updatedAt)
        )
        try await client.upsert(dto, table: tags)
    }

    func deleteTag(id: UUID) async throws {
        try await client.delete(table: tags, id: id)
    }

    // MARK: Categories

    func fetchCategories(since: Date? = nil) async throws -> [RemoteCategoryDTO] {
        try await client.select(table: categories, since: since)
    }

    func upsertCategory(_ category: CategoryModel) async throws {
        let userID = try requireUserID()
        let dto = RemoteCategoryDTO(
            id: category.remoteID ?? category.id,
            userID: userID,
            name: category.name,
            iconName: category.iconName,
            sortOrder: category.sortOrder,
            createdAt: RemoteDate(category.createdAt),
            updatedAt: RemoteDate(category.updatedAt)
        )
        try await client.upsert(dto, table: categories)
    }

    func deleteCategory(id: UUID) async throws {
        try await client.delete(table: categories, id: id)
    }

    // MARK: Check-ins

    func fetchCheckIns(since: Date? = nil) async throws -> [RemoteCheckInDTO] {
        try await client.select(table: checkIns, since: since)
    }

    func upsertCheckIn(_ checkIn: CheckIn) async throws {
        let userID = try requireUserID()
        let dto = RemoteCheckInDTO(
            id: checkIn.remoteID ?? checkIn.id,
            userID: userID,
            emotion: checkIn.emotion.rawValue,
            intensity: checkIn.intensity,
            supportNeed: checkIn.supportNeed?.rawValue,
            optionalNote: checkIn.noteForUpload,
            safetyState: checkIn.safetyState.rawValue,
            recommendationSessionID: checkIn.recommendationSessionID,
            completedAt: checkIn.completedAt.map(RemoteDate.init),
            createdAt: RemoteDate(checkIn.createdAt),
            updatedAt: RemoteDate(checkIn.completedAt ?? checkIn.createdAt)
        )
        try await client.upsert(dto, table: checkIns)
    }

    func deleteCheckIn(id: UUID) async throws {
        try await client.delete(table: checkIns, id: id)
    }

    // MARK: Feedback

    func fetchFeedback(since: Date? = nil) async throws -> [RemoteRecommendationFeedbackDTO] {
        try await client.select(table: feedback, since: since)
    }

    func upsertFeedback(_ item: RecommendationFeedback) async throws {
        let userID = try requireUserID()
        let dto = RemoteRecommendationFeedbackDTO(
            id: item.remoteID ?? item.id,
            userID: userID,
            recommendationSessionID: item.recommendationSessionID,
            checkInID: item.checkInID,
            evidenceEntryID: item.evidenceEntryID,
            guidedContentID: item.guidedContentID,
            response: item.response.rawValue,
            emotionAtTime: item.emotionAtTime?.rawValue,
            supportNeedAtTime: item.supportNeedAtTime?.rawValue,
            createdAt: RemoteDate(item.createdAt)
        )
        try await client.upsert(dto, table: feedback)
    }

    // MARK: Profile

    func upsertProfile(_ profile: AppProfile) async throws {
        let userID = try requireUserID()
        let dto = RemoteProfileDTO(profile: profile, userID: userID)
        try await client.upsert(dto, table: profiles)
    }

    func fetchProfiles() async throws -> [RemoteProfileDTO] {
        try await client.select(table: profiles, since: nil)
    }

    // MARK: Reminders

    func upsertReminder(_ schedule: ReminderSchedule) async throws {
        let userID = try requireUserID()
        let dto = RemoteReminderPreferenceDTO(
            id: schedule.remoteID ?? schedule.id,
            userID: userID,
            isEnabled: schedule.isEnabled,
            selectedWeekdays: schedule.selectedWeekdays,
            deliveryHour: schedule.deliveryHour,
            deliveryMinute: schedule.deliveryMinute,
            frequency: schedule.frequency.rawValue,
            allowedCategoryIDs: schedule.allowedCategoryIDs,
            genericPreviewOnly: schedule.genericPreviewOnly,
            lastScheduledAt: schedule.lastScheduledAt.map(RemoteDate.init),
            createdAt: RemoteDate(schedule.createdAt),
            updatedAt: RemoteDate(schedule.updatedAt)
        )
        try await client.upsert(dto, table: reminders)
    }

    func fetchReminders() async throws -> [RemoteReminderPreferenceDTO] {
        try await client.select(table: reminders, since: nil)
    }

    // MARK: Meaningful dates

    func upsertMeaningfulDate(_ reminder: MeaningfulDateReminder) async throws {
        let userID = try requireUserID()
        let dto = RemoteMeaningfulDateReminderDTO(
            id: reminder.remoteID ?? reminder.id,
            userID: userID,
            evidenceEntryID: reminder.evidenceEntryID,
            date: RemoteDate(reminder.date),
            recurrence: reminder.recurrence.rawValue,
            enabled: reminder.enabled,
            label: reminder.label,
            reminderHour: reminder.reminderHour,
            reminderMinute: reminder.reminderMinute,
            createdAt: RemoteDate(reminder.createdAt),
            updatedAt: RemoteDate(reminder.updatedAt)
        )
        try await client.upsert(dto, table: meaningfulDates)
    }

    func fetchMeaningfulDates(since: Date? = nil) async throws -> [RemoteMeaningfulDateReminderDTO] {
        try await client.select(table: meaningfulDates, since: since)
    }

    func deleteMeaningfulDate(id: UUID) async throws {
        try await client.delete(table: meaningfulDates, id: id)
    }
}

/// Adapter so SyncCoordinator can push/pull entries through RemoteEvidenceRepositories.
struct RemoteEvidenceEntrySyncAdapter: RemoteEvidenceEntrySyncing {
    let repositories: RemoteEvidenceRepositories

    func pushEntry(_ dto: RemoteEvidenceEntryDTO) async throws {
        try await repositories.client.upsert(dto, table: "evidence_entries")
    }

    func pullEntries(since: Date?) async throws -> [RemoteEvidenceEntryDTO] {
        try await repositories.fetchEntries(since: since)
    }

    func deleteEntry(id: UUID) async throws {
        try await repositories.deleteEntry(id: id)
    }
}

/// Placeholder remote repos that throw `notConfigured` until Supabase is wired.
struct UnconfiguredRemoteEvidenceRepositories {
    func fetchEntries(since: Date? = nil) async throws -> [RemoteEvidenceEntryDTO] {
        throw RemoteRepositoryError.notConfigured
    }

    func upsertEntry(_ entry: EvidenceEntry) async throws {
        throw RemoteRepositoryError.notConfigured
    }

    func deleteEntry(id: UUID) async throws {
        throw RemoteRepositoryError.notConfigured
    }
}
