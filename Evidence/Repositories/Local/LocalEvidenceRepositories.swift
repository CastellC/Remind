import Foundation
import SwiftData

// MARK: - Entries

@MainActor
final class LocalEvidenceEntryRepository: EvidenceEntryRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll(includeArchived: Bool) async throws -> [EvidenceEntry] {
        let all = try context.fetch(
            FetchDescriptor<EvidenceEntry>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        )
        return all.filter { entry in
            if entry.deletedAt != nil { return false }
            if !includeArchived && entry.isArchived { return false }
            return true
        }
    }

    func fetch(id: UUID) async throws -> EvidenceEntry? {
        var descriptor = FetchDescriptor<EvidenceEntry>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func fetchFavorites() async throws -> [EvidenceEntry] {
        let descriptor = FetchDescriptor<EvidenceEntry>(
            predicate: #Predicate { $0.isFavorite == true && $0.isArchived == false },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).filter { $0.deletedAt == nil && !$0.pendingDeletion }
    }

    func fetchPendingSync() async throws -> [EvidenceEntry] {
        try context.fetch(FetchDescriptor<EvidenceEntry>()).filter {
            $0.syncStatus == .pendingUpload
                || $0.syncStatus == .pendingDeletion
                || $0.syncStatus == .failed
                || $0.syncStatus == .syncing
                || $0.pendingDeletion
        }
    }

    func search(query: String) async throws -> [EvidenceEntry] {
        let all = try await fetchAll(includeArchived: false)
        return EvidenceSearchService.filter(all, query: query) { EvidenceSearchableFields(entry: $0) }
    }

    func save(_ entry: EvidenceEntry) async throws {
        if entry.modelContext == nil {
            context.insert(entry)
        }
        entry.touch()
        try context.save()
    }

    func upsert(_ entry: EvidenceEntry) async throws {
        if let existing = try await fetch(id: entry.id), existing !== entry {
            existing.title = entry.title
            existing.bodyText = entry.bodyText
            existing.entryType = entry.entryType
            existing.sourceType = entry.sourceType
            existing.sourceName = entry.sourceName
            existing.sourceContext = entry.sourceContext
            existing.meaningPromptAnswer = entry.meaningPromptAnswer
            existing.isFavorite = entry.isFavorite
            existing.isArchived = entry.isArchived
            existing.isSensitive = entry.isSensitive
            existing.excludeFromCheckIns = entry.excludeFromCheckIns
            existing.excludeFromNotifications = entry.excludeFromNotifications
            existing.localImageFileName = entry.localImageFileName
            existing.remoteMediaPath = entry.remoteMediaPath
            existing.accessibilityDescription = entry.accessibilityDescription
            existing.syncStatus = entry.syncStatus
            existing.pendingDeletion = entry.pendingDeletion
            existing.remoteID = entry.remoteID
            existing.ownerUserID = entry.ownerUserID
            existing.serverUpdatedAt = entry.serverUpdatedAt
            existing.deletedAt = entry.deletedAt
            existing.updatedAt = entry.updatedAt
            try context.save()
        } else {
            try await save(entry)
        }
    }

    func archive(id: UUID) async throws {
        guard let entry = try await fetch(id: id) else { return }
        entry.isArchived = true
        entry.markPendingUpload()
        try context.save()
    }

    func restore(id: UUID) async throws {
        guard let entry = try await fetch(id: id) else { return }
        entry.isArchived = false
        entry.markPendingUpload()
        try context.save()
    }

    func markPendingDeletion(id: UUID) async throws {
        guard let entry = try await fetch(id: id) else { return }
        entry.pendingDeletion = true
        entry.syncStatus = .pendingDeletion
        entry.touch()
        try context.save()
    }

    func deletePermanently(id: UUID) async throws {
        guard let entry = try await fetch(id: id) else { return }
        context.delete(entry)
        try context.save()
    }

    func deleteAllLocal() async throws {
        for entry in try context.fetch(FetchDescriptor<EvidenceEntry>()) {
            context.delete(entry)
        }
        try context.save()
    }
}

// MARK: - Tags

@MainActor
final class LocalTagRepository: TagRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() async throws -> [EvidenceTag] {
        try context.fetch(FetchDescriptor<EvidenceTag>(sortBy: [SortDescriptor(\.name)]))
    }

    func fetch(id: UUID) async throws -> EvidenceTag? {
        try context.fetch(FetchDescriptor<EvidenceTag>(predicate: #Predicate { $0.id == id })).first
    }

    func fetch(tagType: TagType) async throws -> [EvidenceTag] {
        let raw = tagType.rawValue
        return try context.fetch(FetchDescriptor<EvidenceTag>()).filter { $0.tagTypeRaw == raw }
    }

    func save(_ tag: EvidenceTag) async throws {
        if tag.modelContext == nil { context.insert(tag) }
        tag.touch()
        try context.save()
    }

    func upsert(_ tag: EvidenceTag) async throws {
        try await save(tag)
    }

    func delete(id: UUID) async throws {
        if let tag = try await fetch(id: id) {
            context.delete(tag)
            try context.save()
        }
    }

    func deleteAllLocal() async throws {
        for tag in try context.fetch(FetchDescriptor<EvidenceTag>()) {
            context.delete(tag)
        }
        try context.save()
    }
}

// MARK: - Categories

@MainActor
final class LocalCategoryRepository: CategoryRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() async throws -> [CategoryModel] {
        try context.fetch(FetchDescriptor<CategoryModel>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    func fetch(id: UUID) async throws -> CategoryModel? {
        try context.fetch(FetchDescriptor<CategoryModel>(predicate: #Predicate { $0.id == id })).first
    }

    func save(_ category: CategoryModel) async throws {
        if category.modelContext == nil { context.insert(category) }
        category.touch()
        try context.save()
    }

    func upsert(_ category: CategoryModel) async throws {
        try await save(category)
    }

    func delete(id: UUID) async throws {
        if let item = try await fetch(id: id) {
            context.delete(item)
            try context.save()
        }
    }

    func deleteAllLocal() async throws {
        for item in try context.fetch(FetchDescriptor<CategoryModel>()) {
            context.delete(item)
        }
        try context.save()
    }
}

// MARK: - Check-ins

@MainActor
final class LocalCheckInRepository: CheckInRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() async throws -> [CheckIn] {
        try context.fetch(FetchDescriptor<CheckIn>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
    }

    func fetch(id: UUID) async throws -> CheckIn? {
        try context.fetch(FetchDescriptor<CheckIn>(predicate: #Predicate { $0.id == id })).first
    }

    func fetchRecent(limit: Int) async throws -> [CheckIn] {
        var descriptor = FetchDescriptor<CheckIn>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = max(0, limit)
        return try context.fetch(descriptor)
    }

    func save(_ checkIn: CheckIn) async throws {
        if checkIn.modelContext == nil { context.insert(checkIn) }
        try context.save()
    }

    func upsert(_ checkIn: CheckIn) async throws {
        try await save(checkIn)
    }

    func delete(id: UUID) async throws {
        if let item = try await fetch(id: id) {
            context.delete(item)
            try context.save()
        }
    }

    func deleteAllLocal() async throws {
        for item in try context.fetch(FetchDescriptor<CheckIn>()) {
            context.delete(item)
        }
        try context.save()
    }
}

// MARK: - Feedback

@MainActor
final class LocalFeedbackRepository: FeedbackRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() async throws -> [RecommendationFeedback] {
        try context.fetch(
            FetchDescriptor<RecommendationFeedback>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )
    }

    func fetch(forEntryID entryID: UUID) async throws -> [RecommendationFeedback] {
        try context.fetch(FetchDescriptor<RecommendationFeedback>()).filter { $0.evidenceEntryID == entryID }
    }

    func fetchRecent(limit: Int) async throws -> [RecommendationFeedback] {
        var descriptor = FetchDescriptor<RecommendationFeedback>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = max(0, limit)
        return try context.fetch(descriptor)
    }

    func save(_ feedback: RecommendationFeedback) async throws {
        if feedback.modelContext == nil { context.insert(feedback) }
        try context.save()
    }

    func upsert(_ feedback: RecommendationFeedback) async throws {
        try await save(feedback)
    }

    func delete(id: UUID) async throws {
        if let item = try context.fetch(
            FetchDescriptor<RecommendationFeedback>(predicate: #Predicate { $0.id == id })
        ).first {
            context.delete(item)
            try context.save()
        }
    }

    func deleteAllLocal() async throws {
        for item in try context.fetch(FetchDescriptor<RecommendationFeedback>()) {
            context.delete(item)
        }
        try context.save()
    }
}

// MARK: - Profile

@MainActor
final class LocalProfileRepository: ProfileRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchProfile() async throws -> AppProfile? {
        try context.fetch(FetchDescriptor<AppProfile>()).first
    }

    func save(_ profile: AppProfile) async throws {
        if profile.modelContext == nil { context.insert(profile) }
        profile.touch()
        try context.save()
    }

    func upsert(_ profile: AppProfile) async throws {
        try await save(profile)
    }

    func updateLastSuccessfulSyncAt(_ date: Date?) async throws {
        if let profile = try await fetchProfile() {
            profile.lastSuccessfulSyncAt = date
            profile.touch()
            try context.save()
        }
    }

    func deleteAllLocal() async throws {
        for item in try context.fetch(FetchDescriptor<AppProfile>()) {
            context.delete(item)
        }
        try context.save()
    }
}

// MARK: - Reminders

@MainActor
final class LocalReminderRepository: ReminderRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchSchedule() async throws -> ReminderSchedule? {
        try context.fetch(FetchDescriptor<ReminderSchedule>()).first
    }

    func save(_ schedule: ReminderSchedule) async throws {
        if schedule.modelContext == nil { context.insert(schedule) }
        schedule.touch()
        try context.save()
    }

    func upsert(_ schedule: ReminderSchedule) async throws {
        try await save(schedule)
    }

    func deleteSchedule() async throws {
        try await deleteAllLocal()
    }

    func deleteAllLocal() async throws {
        for item in try context.fetch(FetchDescriptor<ReminderSchedule>()) {
            context.delete(item)
        }
        try context.save()
    }
}

// MARK: - Meaningful dates

@MainActor
final class LocalMeaningfulDateRepository: MeaningfulDateRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() async throws -> [MeaningfulDateReminder] {
        try context.fetch(FetchDescriptor<MeaningfulDateReminder>(sortBy: [SortDescriptor(\.date)]))
    }

    func fetch(forEntryID entryID: UUID) async throws -> [MeaningfulDateReminder] {
        try context.fetch(FetchDescriptor<MeaningfulDateReminder>()).filter { $0.evidenceEntryID == entryID }
    }

    func save(_ reminder: MeaningfulDateReminder) async throws {
        if reminder.modelContext == nil { context.insert(reminder) }
        reminder.touch()
        try context.save()
    }

    func upsert(_ reminder: MeaningfulDateReminder) async throws {
        try await save(reminder)
    }

    func delete(id: UUID) async throws {
        if let item = try context.fetch(
            FetchDescriptor<MeaningfulDateReminder>(predicate: #Predicate { $0.id == id })
        ).first {
            context.delete(item)
            try context.save()
        }
    }

    func deleteAllLocal() async throws {
        for item in try context.fetch(FetchDescriptor<MeaningfulDateReminder>()) {
            context.delete(item)
        }
        try context.save()
    }
}

/// Convenience factory for all local repositories sharing one ModelContext.
@MainActor
struct LocalRepositoryBundle {
    let entries: LocalEvidenceEntryRepository
    let tags: LocalTagRepository
    let categories: LocalCategoryRepository
    let checkIns: LocalCheckInRepository
    let feedback: LocalFeedbackRepository
    let profile: LocalProfileRepository
    let reminders: LocalReminderRepository
    let meaningfulDates: LocalMeaningfulDateRepository

    init(context: ModelContext) {
        entries = LocalEvidenceEntryRepository(context: context)
        tags = LocalTagRepository(context: context)
        categories = LocalCategoryRepository(context: context)
        checkIns = LocalCheckInRepository(context: context)
        feedback = LocalFeedbackRepository(context: context)
        profile = LocalProfileRepository(context: context)
        reminders = LocalReminderRepository(context: context)
        meaningfulDates = LocalMeaningfulDateRepository(context: context)
    }
}
