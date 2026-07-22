import XCTest
import SwiftData
@testable import Evidence

@MainActor
final class DataDeletionTests: XCTestCase {
    private var container: ModelContainer!
    private var repos: LocalRepositoryBundle!
    private var imageStorage: InMemoryImageStorageService!
    private var notifications: MockNotificationService!
    private var auth: MockAuthenticationService!
    private var deletionService: DataDeletionService!

    override func setUp() async throws {
        try await super.setUp()
        container = try ModelContainer.evidence(inMemory: true)
        let context = container.mainContext
        repos = LocalRepositoryBundle(context: context)
        imageStorage = InMemoryImageStorageService()
        notifications = MockNotificationService()
        notifications.authorizationGranted = true
        notifications.scheduledCount = 3
        auth = MockAuthenticationService(currentUserID: UUID())

        deletionService = DataDeletionService(
            entryRepository: repos.entries,
            tagRepository: repos.tags,
            categoryRepository: repos.categories,
            checkInRepository: repos.checkIns,
            feedbackRepository: repos.feedback,
            profileRepository: repos.profile,
            reminderRepository: repos.reminders,
            meaningfulDateRepository: repos.meaningfulDates,
            imageStorage: imageStorage,
            notificationService: notifications,
            mediaService: UnavailableMediaService(),
            auth: auth,
            remoteEntries: StubRemoteEvidenceEntrySync(),
            dateProvider: FixedDateProvider(now: Date(timeIntervalSince1970: 1_720_000_000))
        )
    }

    override func tearDown() async throws {
        deletionService = nil
        auth = nil
        notifications = nil
        imageStorage = nil
        repos = nil
        container = nil
        try await super.tearDown()
    }

    private func seedLocalData(resetOnboardingProfile: Bool = true) async throws {
        let profile = AppProfile(
            displayName: "Tester",
            selectedUseCases: [.rememberKindWords],
            onboardingCompletedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        try await repos.profile.save(profile)

        let entry = EvidenceEntry(
            title: "To delete",
            bodyText: "Body",
            meaningPromptAnswer: "Someone believed in me",
            localImageFileName: "seed-display.jpg"
        )
        try await repos.entries.save(entry)

        let tag = EvidenceTag(name: "Anxious", tagType: .emotion)
        try await repos.tags.save(tag)

        let category = CategoryModel(name: "Support", iconName: "heart", sortOrder: 0)
        try await repos.categories.save(category)

        try await repos.reminders.save(ReminderSchedule(isEnabled: true))
        try await repos.checkIns.save(
            CheckIn(emotion: .anxious, supportNeed: .reassurance)
        )

        _ = resetOnboardingProfile
    }

    func testDeleteLocalDataRemovesEntriesAndCancelsNotifications() async throws {
        try await seedLocalData()

        let report = await deletionService.deleteLocalData(resetOnboarding: false)

        XCTAssertTrue(report.deletedLocalData)
        XCTAssertTrue(report.deletedLocalImages)
        XCTAssertTrue(report.cancelledNotifications)
        XCTAssertTrue(report.failures.isEmpty)
        XCTAssertEqual(notifications.scheduledCount, 0)

        let entries = try await repos.entries.fetchAll(includeArchived: true)
        XCTAssertTrue(entries.isEmpty)

        let tags = try await repos.tags.fetchAll()
        XCTAssertTrue(tags.isEmpty)

        let categories = try await repos.categories.fetchAll()
        XCTAssertTrue(categories.isEmpty)

        let profile = try await repos.profile.fetchProfile()
        XCTAssertNil(profile)
    }

    func testDeleteLocalDataCanResetOnboardingInsteadOfDeletingProfile() async throws {
        try await seedLocalData()

        let report = await deletionService.deleteLocalData(resetOnboarding: true)
        XCTAssertTrue(report.deletedLocalData)
        XCTAssertTrue(report.failures.isEmpty)

        let profile = try await repos.profile.fetchProfile()
        XCTAssertNotNil(profile)
        XCTAssertNil(profile?.onboardingCompletedAt)
        XCTAssertTrue(profile?.selectedUseCases.isEmpty ?? false)

        let entries = try await repos.entries.fetchAll(includeArchived: true)
        XCTAssertTrue(entries.isEmpty)
    }

    func testDeleteCloudDataRequiresSignIn() async {
        auth = MockAuthenticationService(currentUserID: nil)
        deletionService = DataDeletionService(
            entryRepository: repos.entries,
            tagRepository: repos.tags,
            categoryRepository: repos.categories,
            checkInRepository: repos.checkIns,
            feedbackRepository: repos.feedback,
            profileRepository: repos.profile,
            reminderRepository: repos.reminders,
            meaningfulDateRepository: repos.meaningfulDates,
            imageStorage: imageStorage,
            notificationService: notifications,
            mediaService: UnavailableMediaService(),
            auth: auth,
            remoteEntries: StubRemoteEvidenceEntrySync(),
            dateProvider: FixedDateProvider(now: Date(timeIntervalSince1970: 1_720_000_000))
        )

        let report = await deletionService.deleteCloudData()
        XCTAssertFalse(report.deletedCloudData)
        XCTAssertFalse(report.failures.isEmpty)
    }

    func testDeletionReportSucceededFully() {
        var report = DeletionReport.empty
        XCTAssertTrue(report.succeededFully)
        report.failures.append("Something failed")
        XCTAssertFalse(report.succeededFully)
    }
}
