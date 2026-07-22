import Combine
import Foundation

#if canImport(Supabase)
import Supabase
#endif

/// Application-wide configuration and service factory.
/// Secrets are never hardcoded — values come from Info.plist / xcconfig injection.
/// Feature screens should depend on `AppContainer` rather than constructing services directly.
@MainActor
final class AppEnvironment: ObservableObject {
    struct FeatureFlags: Equatable, Sendable {
        var cloudSyncEnabled: Bool
        var notificationsEnabled: Bool
        var appLockAvailable: Bool
        var sampleDataSeedingAllowed: Bool

        static let `default` = FeatureFlags(
            cloudSyncEnabled: true,
            notificationsEnabled: true,
            appLockAvailable: true,
            sampleDataSeedingAllowed: SampleData.enabled
        )
    }

    let supabaseURL: String
    let supabaseAnonKey: String
    let featureFlags: FeatureFlags

    let dateProvider: any DateProviding
    let uuidProvider: any UUIDProviding
    let networkMonitor: any NetworkStatusProviding

    private(set) lazy var authentication: any AuthenticationServing = makeAuthentication()
    private(set) lazy var notificationService: any NotificationServing = LocalNotificationService(dateProvider: dateProvider)
    private(set) lazy var appLock: any AppLockServing = AppLockService(dateProvider: dateProvider)
    private(set) lazy var safetyDetector: any SafetyLanguageDetecting = LocalSafetyLanguageDetector()
    private(set) lazy var seedData: any SeedDataServing = SeedDataService(
        dateProvider: dateProvider,
        uuidProvider: uuidProvider
    )

    private(set) var imageStorage: (any ImageStorageServing)?
    private(set) var mediaService: any MediaServing
    private(set) var remoteEntrySync: any RemoteEvidenceEntrySyncing

    var isSupabaseConfigured: Bool {
        let url = supabaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = supabaseAnonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return !url.isEmpty && !key.isEmpty && URL(string: url) != nil
    }

    init(
        supabaseURL: String? = nil,
        supabaseAnonKey: String? = nil,
        featureFlags: FeatureFlags = .default,
        dateProvider: any DateProviding = SystemDateProvider(),
        uuidProvider: any UUIDProviding = SystemUUIDProvider(),
        networkMonitor: (any NetworkStatusProviding)? = nil
    ) {
        let bundle = Bundle.main
        self.supabaseURL = Self.sanitizedInfoValue(
            supabaseURL ?? bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
        )
        self.supabaseAnonKey = Self.sanitizedInfoValue(
            supabaseAnonKey ?? bundle.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
        )
        self.featureFlags = featureFlags
        self.dateProvider = dateProvider
        self.uuidProvider = uuidProvider
        self.networkMonitor = networkMonitor ?? NetworkMonitor()

        self.imageStorage = try? LocalImageStorageService(uuidProvider: uuidProvider)

        #if canImport(Supabase)
        if let url = URL(string: self.supabaseURL), !self.supabaseAnonKey.isEmpty {
            let client = SupabaseClient(supabaseURL: url, supabaseKey: self.supabaseAnonKey)
            self.mediaService = SupabaseMediaService(client: client)
            self.remoteEntrySync = SupabaseRemoteEvidenceEntrySync(client: client)
        } else {
            self.mediaService = UnavailableMediaService()
            self.remoteEntrySync = StubRemoteEvidenceEntrySync()
        }
        #else
        self.mediaService = UnavailableMediaService()
        self.remoteEntrySync = StubRemoteEvidenceEntrySync()
        #endif
    }

    /// Preview / test environment with empty credentials and fixed providers.
    static func preview(
        date: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> AppEnvironment {
        AppEnvironment(
            supabaseURL: "",
            supabaseAnonKey: "",
            featureFlags: .default,
            dateProvider: FixedDateProvider(now: date),
            uuidProvider: FixedUUIDProvider(uuids: []),
            networkMonitor: FixedNetworkMonitor(isConnected: true)
        )
    }

    func makeAuthentication() -> any AuthenticationServing {
        #if canImport(Supabase)
        if isSupabaseConfigured, let url = URL(string: supabaseURL) {
            let client = SupabaseClient(supabaseURL: url, supabaseKey: supabaseAnonKey)
            return SupabaseAuthenticationService(client: client)
        }
        #endif
        return UnavailableAuthenticationService()
    }

    func makeRecommendationEngine(seed: UInt64? = nil) -> RecommendationEngine {
        if let seed {
            return RecommendationEngine(
                dateProvider: dateProvider,
                randomNumberGenerator: SeededGenerator(seed: seed)
            )
        }
        return RecommendationEngine(dateProvider: dateProvider)
    }

    func makeSyncCoordinator(dependencies: SyncDependencies) -> SyncCoordinator {
        SyncCoordinator(dependencies: dependencies)
    }

    /// Treats missing or placeholder Info.plist values as empty.
    private static func sanitizedInfoValue(_ raw: String?) -> String {
        guard let raw else { return "" }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        if trimmed.hasPrefix("$(") { return "" }
        if trimmed == "YOUR_SUPABASE_URL" || trimmed == "YOUR_SUPABASE_ANON_KEY" { return "" }
        return trimmed
    }
}
