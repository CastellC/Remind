import Foundation
import SwiftData

/// Coordinates offline-first push/pull synchronization.
@MainActor
protocol SyncCoordinating: AnyObject {
    var isSyncing: Bool { get }
    var lastErrorMessage: String? { get }

    func syncNow() async
    func enqueuePendingWork() async
}

struct SyncDependencies {
    var entryRepository: any EvidenceEntryRepository
    var tagRepository: any TagRepository
    var categoryRepository: any CategoryRepository
    var checkInRepository: any CheckInRepository
    var feedbackRepository: any FeedbackRepository
    var profileRepository: any ProfileRepository
    var reminderRepository: any ReminderRepository
    var meaningfulDateRepository: any MeaningfulDateRepository
    var remoteEntries: any RemoteEvidenceEntrySyncing
    var mediaService: any MediaServing
    var imageStorage: any ImageStorageServing
    var network: any NetworkStatusProviding
    var auth: any AuthenticationServing
    var dateProvider: any DateProviding
}

protocol RemoteEvidenceEntrySyncing: Sendable {
    func pushEntry(_ dto: RemoteEvidenceEntryDTO) async throws
    func pullEntries(since: Date?) async throws -> [RemoteEvidenceEntryDTO]
    func deleteEntry(id: UUID) async throws
}

/// Default sync coordinator: push pending uploads/deletions, pull remote changes,
/// resolve conflicts by `updatedAt`, preserve a conflict copy when needed.
@MainActor
final class SyncCoordinator: SyncCoordinating {
    private let dependencies: SyncDependencies
    private(set) var isSyncing = false
    private(set) var lastErrorMessage: String?
    private var backoffSeconds: TimeInterval = 1
    private let maxBackoff: TimeInterval = 60

    init(dependencies: SyncDependencies) {
        self.dependencies = dependencies
    }

    func enqueuePendingWork() async {
        // Local repositories already mark pendingUpload / pendingDeletion on write.
        // This hook exists for UI to request a sync when the network returns.
        guard dependencies.network.isConnected else { return }
        await syncNow()
    }

    func syncNow() async {
        guard !isSyncing else { return }
        guard dependencies.network.isConnected else {
            lastErrorMessage = nil
            return
        }
        guard let userID = dependencies.auth.currentUserID else {
            lastErrorMessage = nil
            return
        }

        isSyncing = true
        lastErrorMessage = nil
        defer { isSyncing = false }

        do {
            try await pushPendingDeletions(userID: userID)
            try await pushPendingUploads(userID: userID)
            try await pullRemoteChanges(userID: userID)

            if var profile = try await dependencies.profileRepository.fetchProfile() {
                profile.lastSuccessfulSyncAt = dependencies.dateProvider.now
                profile.touch(dependencies.dateProvider.now)
                try await dependencies.profileRepository.save(profile)
            }

            backoffSeconds = 1
        } catch {
            lastErrorMessage = "Sync could not finish. Your local collection is still available."
            backoffSeconds = min(maxBackoff, backoffSeconds * 2)
            try? await Task.sleep(nanoseconds: UInt64(backoffSeconds * 1_000_000_000))
        }
    }

    // MARK: - Push

    private func pushPendingDeletions(userID: UUID) async throws {
        let pending = try await dependencies.entryRepository.fetchPendingSync()
        for entry in pending where entry.syncStatus == .pendingDeletion || entry.pendingDeletion {
            let remoteID = entry.remoteID ?? entry.id
            if let path = entry.remoteMediaPath, MediaPathBuilder.isValid(path, userID: userID) {
                try? await dependencies.mediaService.delete(path: path)
            }
            try await dependencies.remoteEntries.deleteEntry(id: remoteID)
            try await dependencies.entryRepository.deletePermanently(id: entry.id)
            if let fileName = entry.localImageFileName {
                let thumb = fileName.replacingOccurrences(of: "-display.jpg", with: "-thumb.jpg")
                try? await dependencies.imageStorage.deleteImages(
                    displayFileName: fileName,
                    thumbnailFileName: thumb
                )
            }
        }
    }

    private func pushPendingUploads(userID: UUID) async throws {
        let pending = try await dependencies.entryRepository.fetchPendingSync()
        for entry in pending where entry.syncStatus == .pendingUpload || entry.syncStatus == .failed {
            entry.ownerUserID = userID
            entry.syncStatus = .syncing

            if let localName = entry.localImageFileName,
               entry.remoteMediaPath == nil,
               let image = try? await dependencies.imageStorage.loadDisplayImage(fileName: localName),
               let data = image.jpegData(compressionQuality: 0.85) {
                let assetID = UUID()
                let path = try await dependencies.mediaService.upload(
                    data: data,
                    userID: userID,
                    entryID: entry.id,
                    assetID: assetID,
                    fileExtension: "jpg",
                    contentType: "image/jpeg"
                )
                entry.remoteMediaPath = path
            }

            let dto = RemoteEvidenceEntryDTO(entry: entry, userID: userID)
            try await dependencies.remoteEntries.pushEntry(dto)
            entry.markSynced(remoteID: dto.id, serverUpdatedAt: dependencies.dateProvider.now)
            try await dependencies.entryRepository.save(entry)
        }
    }

    // MARK: - Pull

    private func pullRemoteChanges(userID: UUID) async throws {
        let profile = try await dependencies.profileRepository.fetchProfile()
        let since = profile?.lastSuccessfulSyncAt
        let remote = try await dependencies.remoteEntries.pullEntries(since: since)

        for dto in remote {
            if let local = try await dependencies.entryRepository.fetch(id: dto.id) {
                try await merge(local: local, remote: dto)
            } else if let local = try await findByRemoteID(dto.id) {
                try await merge(local: local, remote: dto)
            } else {
                let created = EvidenceEntry.fromRemote(dto)
                try await dependencies.entryRepository.upsert(created)
            }
        }
    }

    private func findByRemoteID(_ remoteID: UUID) async throws -> EvidenceEntry? {
        let all = try await dependencies.entryRepository.fetchAll(includeArchived: true)
        return all.first { $0.remoteID == remoteID || $0.id == remoteID }
    }

    private func merge(local: EvidenceEntry, remote: RemoteEvidenceEntryDTO) async throws {
        let remoteUpdated = remote.updatedAt.value
        let localUpdated = local.updatedAt

        if local.syncStatus == .pendingUpload || local.syncStatus == .pendingDeletion {
            // Local pending work wins until push completes; skip overwrite.
            if localUpdated > remoteUpdated {
                return
            }
        }

        if abs(localUpdated.timeIntervalSince(remoteUpdated)) < 1 {
            local.applyRemoteFields(from: remote)
            try await dependencies.entryRepository.save(local)
            return
        }

        if remoteUpdated > localUpdated {
            // Preserve conflict copy before overwrite when local has unsynced edits.
            if local.syncStatus == .failed || local.syncStatus == .conflict || local.syncStatus == .pendingUpload {
                let copy = EvidenceEntry(
                    title: local.title + " (local copy)",
                    bodyText: local.bodyText,
                    entryType: local.entryType,
                    sourceType: local.sourceType,
                    sourceName: local.sourceName,
                    sourceContext: local.sourceContext,
                    meaningPromptAnswer: local.meaningPromptAnswer,
                    localImageFileName: local.localImageFileName,
                    accessibilityDescription: local.accessibilityDescription,
                    syncStatus: .conflict
                )
                copy.isFavorite = local.isFavorite
                copy.isSensitive = local.isSensitive
                try await dependencies.entryRepository.save(copy)
            }
            local.applyRemoteFields(from: remote)
            try await dependencies.entryRepository.save(local)
        } else {
            // Local is newer — mark for upload.
            local.syncStatus = .pendingUpload
            try await dependencies.entryRepository.save(local)
        }
    }
}

// MARK: - Stub remote sync (compiles without live Supabase)

actor StubRemoteEvidenceEntrySync: RemoteEvidenceEntrySyncing {
    func pushEntry(_ dto: RemoteEvidenceEntryDTO) async throws {}
    func pullEntries(since: Date?) async throws -> [RemoteEvidenceEntryDTO] { [] }
    func deleteEntry(id: UUID) async throws {}
}

#if canImport(Supabase)
import Supabase

actor SupabaseRemoteEvidenceEntrySync: RemoteEvidenceEntrySyncing {
    private let client: SupabaseClient
    private let table = "evidence_entries"

    init(client: SupabaseClient) {
        self.client = client
    }

    func pushEntry(_ dto: RemoteEvidenceEntryDTO) async throws {
        try await client.from(table).upsert(dto).execute()
    }

    func pullEntries(since: Date?) async throws -> [RemoteEvidenceEntryDTO] {
        var query = client.from(table).select()
        if let since {
            let formatted = RemoteDTOCoding.iso8601Fractional.string(from: since)
            query = query.gte("updated_at", value: formatted)
        }
        let response: [RemoteEvidenceEntryDTO] = try await query.execute().value
        return response
    }

    func deleteEntry(id: UUID) async throws {
        try await client.from(table).delete().eq("id", value: id.uuidString).execute()
    }
}
#endif
