import Foundation
import Observation
import SwiftData
import UIKit

/// Observable dependency container for feature view models.
@MainActor
@Observable
final class AppContainer {
    let environment: AppEnvironment
    let modelContainer: ModelContainer

    private(set) var entryRepository: any EvidenceEntryRepository
    private(set) var tagRepository: any TagRepository
    private(set) var categoryRepository: any CategoryRepository
    private(set) var checkInRepository: any CheckInRepository
    private(set) var feedbackRepository: any FeedbackRepository
    private(set) var profileRepository: any ProfileRepository
    private(set) var reminderRepository: any ReminderRepository
    private(set) var meaningfulDateRepository: any MeaningfulDateRepository

    private(set) var recommendationEngine: RecommendationEngine
    private(set) var syncCoordinator: SyncCoordinator
    private(set) var exportService: ExportService
    private(set) var deletionService: DataDeletionService

    var guidedContent: [GuidedContentItem] = []
    var hasCompletedInitialSeed = false

    /// Active check-in session state shared between Check-in and Recommendations.
    var activeCheckInID: UUID?
    var preferNeutralGrounding = false
    var showAnotherCount = 0
    var recentlyShownInSession: [RecentlyShownItem] = []

    init(environment: AppEnvironment, modelContainer: ModelContainer) {
        self.environment = environment
        self.modelContainer = modelContainer

        let context = modelContainer.mainContext
        self.entryRepository = LocalEvidenceEntryRepository(context: context)
        self.tagRepository = LocalTagRepository(context: context)
        self.categoryRepository = LocalCategoryRepository(context: context)
        self.checkInRepository = LocalCheckInRepository(context: context)
        self.feedbackRepository = LocalFeedbackRepository(context: context)
        self.profileRepository = LocalProfileRepository(context: context)
        self.reminderRepository = LocalReminderRepository(context: context)
        self.meaningfulDateRepository = LocalMeaningfulDateRepository(context: context)

        self.recommendationEngine = environment.makeRecommendationEngine()

        let imageStorage: any ImageStorageServing = environment.imageStorage
            ?? (try? LocalImageStorageService(uuidProvider: environment.uuidProvider))
            ?? InMemoryImageStorageService()

        let syncDependencies = SyncDependencies(
            entryRepository: entryRepository,
            tagRepository: tagRepository,
            categoryRepository: categoryRepository,
            checkInRepository: checkInRepository,
            feedbackRepository: feedbackRepository,
            profileRepository: profileRepository,
            reminderRepository: reminderRepository,
            meaningfulDateRepository: meaningfulDateRepository,
            remoteEntries: environment.remoteEntrySync,
            mediaService: environment.mediaService,
            imageStorage: imageStorage,
            network: environment.networkMonitor,
            auth: environment.authentication,
            dateProvider: environment.dateProvider
        )
        self.syncCoordinator = environment.makeSyncCoordinator(dependencies: syncDependencies)

        self.exportService = ExportService(
            entryRepository: entryRepository,
            tagRepository: tagRepository,
            categoryRepository: categoryRepository,
            checkInRepository: checkInRepository,
            feedbackRepository: feedbackRepository,
            profileRepository: profileRepository,
            reminderRepository: reminderRepository,
            meaningfulDateRepository: meaningfulDateRepository,
            imageStorage: imageStorage
        )

        self.deletionService = DataDeletionService(
            entryRepository: entryRepository,
            tagRepository: tagRepository,
            categoryRepository: categoryRepository,
            checkInRepository: checkInRepository,
            feedbackRepository: feedbackRepository,
            profileRepository: profileRepository,
            reminderRepository: reminderRepository,
            meaningfulDateRepository: meaningfulDateRepository,
            imageStorage: imageStorage,
            notificationService: environment.notificationService,
            mediaService: environment.mediaService,
            auth: environment.authentication,
            remoteEntries: environment.remoteEntrySync,
            dateProvider: environment.dateProvider
        )
    }

    var authentication: any AuthenticationServing { environment.authentication }
    var appLock: any AppLockServing { environment.appLock }
    var notifications: any NotificationServing { environment.notificationService }
    var safetyDetector: any SafetyLanguageDetecting { environment.safetyDetector }
    var imageStorage: (any ImageStorageServing)? { environment.imageStorage }

    func bootstrap() async {
        guard !hasCompletedInitialSeed else { return }
        do {
            try environment.seedData.seedIfNeeded(context: modelContainer.mainContext)
            guidedContent = (try? environment.seedData.loadGuidedContent(bundle: .main)) ?? []
            if guidedContent.isEmpty {
                guidedContent = (try? GuidedContentItem.load(from: .main)) ?? []
            }
            try await authentication.restoreSession()
            hasCompletedInitialSeed = true
        } catch {
            // Local seed failure must not block the UI; guided content can still fall back later.
            hasCompletedInitialSeed = true
        }
    }

    func ensureProfile() async -> AppProfile {
        let profile: AppProfile
        if let existing = try? await profileRepository.fetchProfile() {
            profile = existing
        } else {
            profile = AppProfile(id: environment.uuidProvider.makeUUID())
            try? await profileRepository.save(profile)
        }

        // UITest launch args: skip onboarding and keep the lock screen out of the way.
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-UITesting") || args.contains("-SkipOnboarding") {
            if profile.onboardingCompletedAt == nil {
                profile.markOnboardingCompleted(at: environment.dateProvider.now)
            }
            profile.appLockEnabled = false
            try? await profileRepository.save(profile)
            environment.appLock.isLockEnabled = false
        }
        return profile
    }

    func resetCheckInSession() {
        activeCheckInID = nil
        preferNeutralGrounding = false
        showAnotherCount = 0
        recentlyShownInSession = []
    }

    static func preview() -> AppContainer {
        let environment = AppEnvironment.preview()
        let container = ModelContainer.evidencePreviewContainer
        return AppContainer(environment: environment, modelContainer: container)
    }
}

/// Fallback when Application Support image storage cannot be created.
actor InMemoryImageStorageService: ImageStorageServing {
    nonisolated let imagesDirectoryURL: URL = FileManager.default.temporaryDirectory.appendingPathComponent("EvidenceImages", isDirectory: true)
    private var store: [String: Data] = [:]

    func saveImageData(_ data: Data) async throws -> StoredImageFilenames {
        let id = UUID().uuidString
        let display = "\(id)-display.jpg"
        let thumb = "\(id)-thumb.jpg"
        store[display] = data
        store[thumb] = data
        return StoredImageFilenames(displayFileName: display, thumbnailFileName: thumb)
    }

    func loadDisplayImage(fileName: String) async throws -> UIImage? {
        guard let data = store[fileName] else { return nil }
        return UIImage(data: data)
    }

    func loadThumbnail(fileName: String) async throws -> UIImage? {
        guard let data = store[fileName] else { return nil }
        return UIImage(data: data)
    }

    func deleteImages(displayFileName: String?, thumbnailFileName: String?) async throws {
        if let displayFileName { store.removeValue(forKey: displayFileName) }
        if let thumbnailFileName { store.removeValue(forKey: thumbnailFileName) }
    }

    func cleanupOrphans(knownFileNames: Set<String>) async throws -> Int {
        let orphans = store.keys.filter { !knownFileNames.contains($0) }
        for key in orphans { store.removeValue(forKey: key) }
        return orphans.count
    }
}
