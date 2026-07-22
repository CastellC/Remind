import Foundation
import SwiftData

/// Named `CategoryModel` to avoid colliding with `Foundation.Category` / other `Category` types.
@Model
final class CategoryModel {
    @Attribute(.unique) var id: UUID
    var remoteID: UUID?
    var ownerUserID: UUID?
    var name: String
    var iconName: String?
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int
    var syncStatusRaw: String

    @Relationship(deleteRule: .cascade, inverse: \EvidenceEntryCategory.category)
    var entryLinks: [EvidenceEntryCategory] = []

    init(
        id: UUID = UUID(),
        remoteID: UUID? = nil,
        ownerUserID: UUID? = nil,
        name: String,
        iconName: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        sortOrder: Int = 0,
        syncStatus: SyncStatus = .localOnly
    ) {
        self.id = id
        self.remoteID = remoteID
        self.ownerUserID = ownerUserID
        self.name = name
        self.iconName = iconName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortOrder = sortOrder
        self.syncStatusRaw = syncStatus.rawValue
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .localOnly }
        set { syncStatusRaw = newValue.rawValue }
    }

    var displayName: String { name }

    func touch(_ date: Date = .now) {
        updatedAt = date
    }
}

/// Typealias for call sites that prefer the product name.
typealias EvidenceCategory = CategoryModel
