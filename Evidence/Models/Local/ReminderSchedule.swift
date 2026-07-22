import Foundation
import SwiftData

@Model
final class ReminderSchedule {
    @Attribute(.unique) var id: UUID
    var remoteID: UUID?
    var ownerUserID: UUID?
    var isEnabled: Bool
    /// JSON-encoded `[Int]` calendar weekdays (1 = Sunday … 7 = Saturday).
    var selectedWeekdaysData: Data
    var deliveryHour: Int
    var deliveryMinute: Int
    var frequencyRaw: String
    /// JSON-encoded `[UUID]` of allowed category IDs. Empty means all categories.
    var allowedCategoryIDsData: Data
    var genericPreviewOnly: Bool
    var lastScheduledAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var syncStatusRaw: String

    init(
        id: UUID = UUID(),
        remoteID: UUID? = nil,
        ownerUserID: UUID? = nil,
        isEnabled: Bool = false,
        selectedWeekdays: [Int] = [2, 3, 4, 5, 6],
        deliveryHour: Int = 9,
        deliveryMinute: Int = 0,
        frequency: ReminderFrequency = .weekdays,
        allowedCategoryIDs: [UUID] = [],
        genericPreviewOnly: Bool = true,
        lastScheduledAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        syncStatus: SyncStatus = .localOnly
    ) {
        self.id = id
        self.remoteID = remoteID
        self.ownerUserID = ownerUserID
        self.isEnabled = isEnabled
        self.selectedWeekdaysData = CodableStorage.encodeIntArray(selectedWeekdays)
        self.deliveryHour = min(23, max(0, deliveryHour))
        self.deliveryMinute = min(59, max(0, deliveryMinute))
        self.frequencyRaw = frequency.rawValue
        self.allowedCategoryIDsData = CodableStorage.encodeUUIDArray(allowedCategoryIDs)
        self.genericPreviewOnly = genericPreviewOnly
        self.lastScheduledAt = lastScheduledAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatusRaw = syncStatus.rawValue
    }

    var selectedWeekdays: [Int] {
        get { CodableStorage.decodeIntArray(from: selectedWeekdaysData).sorted() }
        set {
            selectedWeekdaysData = CodableStorage.encodeIntArray(newValue)
            touch()
        }
    }

    var frequency: ReminderFrequency {
        get { ReminderFrequency(rawValue: frequencyRaw) ?? .weekdays }
        set {
            frequencyRaw = newValue.rawValue
            touch()
        }
    }

    var allowedCategoryIDs: [UUID] {
        get { CodableStorage.decodeUUIDArray(from: allowedCategoryIDsData) }
        set {
            allowedCategoryIDsData = CodableStorage.encodeUUIDArray(newValue)
            touch()
        }
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .localOnly }
        set { syncStatusRaw = newValue.rawValue }
    }

    var allowsAllCategories: Bool {
        allowedCategoryIDs.isEmpty
    }

    var effectiveWeekdays: [Int] {
        switch frequency {
        case .daily, .weekdays:
            return frequency.defaultWeekdays()
        case .custom:
            return selectedWeekdays.isEmpty ? frequency.defaultWeekdays() : selectedWeekdays
        }
    }

    func touch(_ date: Date = .now) {
        updatedAt = date
    }

    func formattedDeliveryTime(locale: Locale = .current) -> String {
        var components = DateComponents()
        components.hour = deliveryHour
        components.minute = deliveryMinute
        let calendar = Calendar.current
        let date = calendar.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
