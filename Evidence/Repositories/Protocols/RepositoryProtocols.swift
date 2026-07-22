import Foundation

// MARK: - Evidence entries

@MainActor
protocol EvidenceEntryRepository: AnyObject {
    func fetchAll(includeArchived: Bool) async throws -> [EvidenceEntry]
    func fetch(id: UUID) async throws -> EvidenceEntry?
    func fetchFavorites() async throws -> [EvidenceEntry]
    func fetchPendingSync() async throws -> [EvidenceEntry]
    func search(query: String) async throws -> [EvidenceEntry]
    func save(_ entry: EvidenceEntry) async throws
    func upsert(_ entry: EvidenceEntry) async throws
    func archive(id: UUID) async throws
    func restore(id: UUID) async throws
    func markPendingDeletion(id: UUID) async throws
    func deletePermanently(id: UUID) async throws
    func deleteAllLocal() async throws
}

// MARK: - Tags

@MainActor
protocol TagRepository: AnyObject {
    func fetchAll() async throws -> [EvidenceTag]
    func fetch(id: UUID) async throws -> EvidenceTag?
    func fetch(tagType: TagType) async throws -> [EvidenceTag]
    func save(_ tag: EvidenceTag) async throws
    func upsert(_ tag: EvidenceTag) async throws
    func delete(id: UUID) async throws
    func deleteAllLocal() async throws
}

// MARK: - Categories

@MainActor
protocol CategoryRepository: AnyObject {
    func fetchAll() async throws -> [CategoryModel]
    func fetch(id: UUID) async throws -> CategoryModel?
    func save(_ category: CategoryModel) async throws
    func upsert(_ category: CategoryModel) async throws
    func delete(id: UUID) async throws
    func deleteAllLocal() async throws
}

// MARK: - Check-ins

@MainActor
protocol CheckInRepository: AnyObject {
    func fetchAll() async throws -> [CheckIn]
    func fetch(id: UUID) async throws -> CheckIn?
    func fetchRecent(limit: Int) async throws -> [CheckIn]
    func save(_ checkIn: CheckIn) async throws
    func upsert(_ checkIn: CheckIn) async throws
    func delete(id: UUID) async throws
    func deleteAllLocal() async throws
}

// MARK: - Feedback

@MainActor
protocol FeedbackRepository: AnyObject {
    func fetchAll() async throws -> [RecommendationFeedback]
    func fetch(forEntryID entryID: UUID) async throws -> [RecommendationFeedback]
    func fetchRecent(limit: Int) async throws -> [RecommendationFeedback]
    func save(_ feedback: RecommendationFeedback) async throws
    func upsert(_ feedback: RecommendationFeedback) async throws
    func delete(id: UUID) async throws
    func deleteAllLocal() async throws
}

// MARK: - Profile

@MainActor
protocol ProfileRepository: AnyObject {
    func fetchProfile() async throws -> AppProfile?
    func save(_ profile: AppProfile) async throws
    func upsert(_ profile: AppProfile) async throws
    func updateLastSuccessfulSyncAt(_ date: Date?) async throws
    func deleteAllLocal() async throws
}

// MARK: - Reminders

@MainActor
protocol ReminderRepository: AnyObject {
    func fetchSchedule() async throws -> ReminderSchedule?
    func save(_ schedule: ReminderSchedule) async throws
    func upsert(_ schedule: ReminderSchedule) async throws
    func deleteSchedule() async throws
    func deleteAllLocal() async throws
}

// MARK: - Meaningful dates

@MainActor
protocol MeaningfulDateRepository: AnyObject {
    func fetchAll() async throws -> [MeaningfulDateReminder]
    func fetch(forEntryID entryID: UUID) async throws -> [MeaningfulDateReminder]
    func save(_ reminder: MeaningfulDateReminder) async throws
    func upsert(_ reminder: MeaningfulDateReminder) async throws
    func delete(id: UUID) async throws
    func deleteAllLocal() async throws
}
