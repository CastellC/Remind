import Foundation
import SwiftData

@Model
final class AppProfile {
    @Attribute(.unique) var id: UUID
    var displayName: String?
    var createdAt: Date
    var updatedAt: Date
    var onboardingCompletedAt: Date?
    /// JSON-encoded `[String]` of `IntendedUseCase.rawValue`.
    var selectedUseCasesData: Data
    var appLockEnabled: Bool
    var notificationPreviewModeRaw: String
    var hasSeenSafetyInformation: Bool
    var cloudSyncEnabled: Bool
    var authenticatedUserID: UUID?
    var lastSuccessfulSyncAt: Date?
    /// When true, optional check-in notes stay on-device and are not uploaded.
    var keepCheckInNotesLocalOnly: Bool

    init(
        id: UUID = UUID(),
        displayName: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        onboardingCompletedAt: Date? = nil,
        selectedUseCases: [IntendedUseCase] = [],
        appLockEnabled: Bool = false,
        notificationPreviewMode: NotificationPreviewMode = .generic,
        hasSeenSafetyInformation: Bool = false,
        cloudSyncEnabled: Bool = false,
        authenticatedUserID: UUID? = nil,
        lastSuccessfulSyncAt: Date? = nil,
        keepCheckInNotesLocalOnly: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.onboardingCompletedAt = onboardingCompletedAt
        self.selectedUseCasesData = CodableStorage.encodeRawRepresentableArray(selectedUseCases)
        self.appLockEnabled = appLockEnabled
        self.notificationPreviewModeRaw = notificationPreviewMode.rawValue
        self.hasSeenSafetyInformation = hasSeenSafetyInformation
        self.cloudSyncEnabled = cloudSyncEnabled
        self.authenticatedUserID = authenticatedUserID
        self.lastSuccessfulSyncAt = lastSuccessfulSyncAt
        self.keepCheckInNotesLocalOnly = keepCheckInNotesLocalOnly
    }

    var selectedUseCases: [IntendedUseCase] {
        get { CodableStorage.decodeRawRepresentableArray(IntendedUseCase.self, from: selectedUseCasesData) }
        set {
            selectedUseCasesData = CodableStorage.encodeRawRepresentableArray(newValue)
            touch()
        }
    }

    var notificationPreviewMode: NotificationPreviewMode {
        get { NotificationPreviewMode(rawValue: notificationPreviewModeRaw) ?? .generic }
        set {
            notificationPreviewModeRaw = newValue.rawValue
            touch()
        }
    }

    var hasCompletedOnboarding: Bool {
        onboardingCompletedAt != nil
    }

    var isAuthenticatedForSync: Bool {
        cloudSyncEnabled && authenticatedUserID != nil
    }

    func touch(_ date: Date = .now) {
        updatedAt = date
    }

    func markOnboardingCompleted(at date: Date = .now) {
        onboardingCompletedAt = date
        touch(date)
    }
}
