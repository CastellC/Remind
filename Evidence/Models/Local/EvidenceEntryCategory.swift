import Foundation
import SwiftData

@Model
final class EvidenceEntryCategory {
    @Attribute(.unique) var id: UUID
    var evidenceEntryID: UUID
    var categoryID: UUID
    var createdAt: Date
    var syncStatusRaw: String

    var entry: EvidenceEntry?
    var category: CategoryModel?

    init(
        id: UUID = UUID(),
        evidenceEntryID: UUID,
        categoryID: UUID,
        createdAt: Date = .now,
        syncStatus: SyncStatus = .localOnly,
        entry: EvidenceEntry? = nil,
        category: CategoryModel? = nil
    ) {
        self.id = id
        self.evidenceEntryID = evidenceEntryID
        self.categoryID = categoryID
        self.createdAt = createdAt
        self.syncStatusRaw = syncStatus.rawValue
        self.entry = entry
        self.category = category
    }

    convenience init(
        entry: EvidenceEntry,
        category: CategoryModel,
        syncStatus: SyncStatus = .localOnly
    ) {
        self.init(
            evidenceEntryID: entry.id,
            categoryID: category.id,
            syncStatus: syncStatus,
            entry: entry,
            category: category
        )
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .localOnly }
        set { syncStatusRaw = newValue.rawValue }
    }
}
