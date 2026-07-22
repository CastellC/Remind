import Foundation

/// Results of a deletion operation that may partially fail.
struct DeletionReport: Equatable, Sendable {
    var deletedLocalData: Bool
    var deletedLocalImages: Bool
    var cancelledNotifications: Bool
    var deletedCloudData: Bool
    var deletedAccount: Bool
    var failures: [String]

    var succeededFully: Bool { failures.isEmpty }

    static var empty: DeletionReport {
        DeletionReport(
            deletedLocalData: false,
            deletedLocalImages: false,
            cancelledNotifications: false,
            deletedCloudData: false,
            deletedAccount: false,
            failures: []
        )
    }
}

protocol DataDeletionServing {
    func deleteLocalData(resetOnboarding: Bool) async -> DeletionReport
    func deleteCloudData() async -> DeletionReport
    func deleteAccountAndAllData(resetOnboarding: Bool) async -> DeletionReport
}

/// Performs destructive data removal. UI must obtain explicit confirmation before calling.
@MainActor
struct DataDeletionService: DataDeletionServing {
    var entryRepository: any EvidenceEntryRepository
    var tagRepository: any TagRepository
    var categoryRepository: any CategoryRepository
    var checkInRepository: any CheckInRepository
    var feedbackRepository: any FeedbackRepository
    var profileRepository: any ProfileRepository
    var reminderRepository: any ReminderRepository
    var meaningfulDateRepository: any MeaningfulDateRepository
    var imageStorage: any ImageStorageServing
    var notificationService: any NotificationServing
    var mediaService: any MediaServing
    var auth: any AuthenticationServing
    var remoteEntries: any RemoteEvidenceEntrySyncing
    var dateProvider: any DateProviding = SystemDateProvider()

    func deleteLocalData(resetOnboarding: Bool) async -> DeletionReport {
        var report = DeletionReport.empty

        await notificationService.cancelAllEvidenceNotifications()
        report.cancelledNotifications = true

        do {
            let entries = try await entryRepository.fetchAll(includeArchived: true)
            let known = Set(entries.compactMap(\.localImageFileName).flatMap { name -> [String] in
                let thumb = name.replacingOccurrences(of: "-display.jpg", with: "-thumb.jpg")
                return [name, thumb]
            })
            // Delete known images, then orphans.
            for name in known {
                if name.contains("-display") {
                    let thumb = name.replacingOccurrences(of: "-display.jpg", with: "-thumb.jpg")
                    try await imageStorage.deleteImages(displayFileName: name, thumbnailFileName: thumb)
                }
            }
            _ = try await imageStorage.cleanupOrphans(knownFileNames: [])
            report.deletedLocalImages = true
        } catch {
            report.failures.append("Some local images could not be removed.")
        }

        do {
            try await meaningfulDateRepository.deleteAllLocal()
            try await feedbackRepository.deleteAllLocal()
            try await checkInRepository.deleteAllLocal()
            try await entryRepository.deleteAllLocal()
            try await tagRepository.deleteAllLocal()
            try await categoryRepository.deleteAllLocal()
            try await reminderRepository.deleteAllLocal()

            if resetOnboarding {
                if let profile = try await profileRepository.fetchProfile() {
                    profile.onboardingCompletedAt = nil
                    profile.selectedUseCases = []
                    profile.touch(dateProvider.now)
                    try await profileRepository.save(profile)
                }
            } else {
                try await profileRepository.deleteAllLocal()
            }
            report.deletedLocalData = true
        } catch {
            report.failures.append("Some local records could not be removed.")
        }

        return report
    }

    func deleteCloudData() async -> DeletionReport {
        var report = DeletionReport.empty
        guard let userID = auth.currentUserID else {
            report.failures.append("Sign in is required to delete cloud data.")
            return report
        }

        do {
            let entries = try await entryRepository.fetchAll(includeArchived: true)
            for entry in entries {
                if let path = entry.remoteMediaPath, MediaPathBuilder.isValid(path, userID: userID) {
                    do {
                        try await mediaService.delete(path: path)
                    } catch {
                        report.failures.append("A remote image could not be deleted.")
                    }
                }
                let remoteID = entry.remoteID ?? entry.id
                do {
                    try await remoteEntries.deleteEntry(id: remoteID)
                } catch {
                    report.failures.append("A remote entry could not be deleted.")
                }
            }
            report.deletedCloudData = report.failures.isEmpty
            if report.failures.isEmpty {
                report.deletedCloudData = true
            }
        } catch {
            report.failures.append("Cloud deletion could not be completed.")
        }

        return report
    }

    func deleteAccountAndAllData(resetOnboarding: Bool) async -> DeletionReport {
        var report = await deleteCloudData()
        let local = await deleteLocalData(resetOnboarding: resetOnboarding)
        report.deletedLocalData = local.deletedLocalData
        report.deletedLocalImages = local.deletedLocalImages
        report.cancelledNotifications = local.cancelledNotifications
        report.failures.append(contentsOf: local.failures)

        do {
            try await auth.deleteAccount()
            report.deletedAccount = true
        } catch {
            report.failures.append("The account could not be deleted. Cloud data deletion may be incomplete.")
        }

        return report
    }
}
