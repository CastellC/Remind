import Foundation

/// Pure conflict resolution decision for sync merge by `updatedAt`.
enum SyncConflictDecision: Equatable, Sendable {
    /// Local has pending work and is newer — skip remote overwrite.
    case skipOverwrite
    /// Timestamps are effectively equal — apply remote fields without a conflict copy.
    case applyRemoteNearEqual
    /// Remote is newer and local has unsynced edits — preserve a local conflict copy, then apply remote.
    case preferRemoteWithLocalCopy
    /// Remote is newer and local is clean — apply remote fields.
    case preferRemote
    /// Local is newer — mark for upload.
    case markLocalPendingUpload
}

/// Deterministic conflict comparison used by `SyncCoordinator` (and unit tests).
enum SyncConflictResolver {
    /// Statuses that indicate local edits may not yet be on the server.
    static let unsyncedLocalStatuses: Set<SyncStatus> = [
        .pendingUpload,
        .pendingDeletion,
        .failed,
        .conflict
    ]

    /// Default near-equality window in seconds (matches coordinator merge tolerance).
    static let defaultNearEqualThreshold: TimeInterval = 1

    static func decide(
        localUpdated: Date,
        remoteUpdated: Date,
        localStatus: SyncStatus,
        nearEqualThreshold: TimeInterval = defaultNearEqualThreshold
    ) -> SyncConflictDecision {
        if localStatus == .pendingUpload || localStatus == .pendingDeletion {
            if localUpdated > remoteUpdated {
                return .skipOverwrite
            }
        }

        if abs(localUpdated.timeIntervalSince(remoteUpdated)) < nearEqualThreshold {
            return .applyRemoteNearEqual
        }

        if remoteUpdated > localUpdated {
            if localStatus == .failed || localStatus == .conflict || localStatus == .pendingUpload {
                return .preferRemoteWithLocalCopy
            }
            return .preferRemote
        }

        return .markLocalPendingUpload
    }

    /// Whether `lhs` is considered newer than `rhs` for sync purposes.
    static func isNewer(_ lhs: Date, than rhs: Date) -> Bool {
        lhs > rhs
    }

    /// Whether two timestamps are within the near-equal threshold.
    static func areNearlyEqual(
        _ lhs: Date,
        _ rhs: Date,
        threshold: TimeInterval = defaultNearEqualThreshold
    ) -> Bool {
        abs(lhs.timeIntervalSince(rhs)) < threshold
    }
}
