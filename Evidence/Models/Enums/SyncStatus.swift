import Foundation

enum SyncStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case localOnly
    case pendingUpload
    case syncing
    case synced
    case pendingDeletion
    case conflict
    case failed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .localOnly:
            return "On this device"
        case .pendingUpload:
            return "Waiting to sync"
        case .syncing:
            return "Syncing"
        case .synced:
            return "Synced"
        case .pendingDeletion:
            return "Waiting to delete"
        case .conflict:
            return "Needs attention"
        case .failed:
            return "Sync failed"
        }
    }

    var needsNetworkWork: Bool {
        switch self {
        case .pendingUpload, .syncing, .pendingDeletion, .conflict, .failed:
            return true
        case .localOnly, .synced:
            return false
        }
    }
}
