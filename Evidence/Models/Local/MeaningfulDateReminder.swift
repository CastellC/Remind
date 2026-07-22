import Foundation
import SwiftData

@Model
final class MeaningfulDateReminder {
    @Attribute(.unique) var id: UUID
    var remoteID: UUID?
    var ownerUserID: UUID?
    var evidenceEntryID: UUID
    var date: Date
    var recurrenceRaw: String
    var enabled: Bool
    var label: String?
    var reminderHour: Int
    var reminderMinute: Int
    var createdAt: Date
    var updatedAt: Date
    var syncStatusRaw: String

    var entry: EvidenceEntry?

    init(
        id: UUID = UUID(),
        remoteID: UUID? = nil,
        ownerUserID: UUID? = nil,
        evidenceEntryID: UUID,
        date: Date,
        recurrence: DateRecurrence = .oneTime,
        enabled: Bool = true,
        label: String? = nil,
        reminderHour: Int = 9,
        reminderMinute: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        syncStatus: SyncStatus = .localOnly,
        entry: EvidenceEntry? = nil
    ) {
        self.id = id
        self.remoteID = remoteID
        self.ownerUserID = ownerUserID
        self.evidenceEntryID = evidenceEntryID
        self.date = date
        self.recurrenceRaw = recurrence.rawValue
        self.enabled = enabled
        self.label = label
        self.reminderHour = min(23, max(0, reminderHour))
        self.reminderMinute = min(59, max(0, reminderMinute))
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatusRaw = syncStatus.rawValue
        self.entry = entry
    }

    convenience init(
        entry: EvidenceEntry,
        date: Date,
        recurrence: DateRecurrence = .oneTime,
        enabled: Bool = true,
        label: String? = nil,
        reminderHour: Int = 9,
        reminderMinute: Int = 0,
        syncStatus: SyncStatus = .localOnly
    ) {
        self.init(
            ownerUserID: entry.ownerUserID,
            evidenceEntryID: entry.id,
            date: date,
            recurrence: recurrence,
            enabled: enabled,
            label: label,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            syncStatus: syncStatus,
            entry: entry
        )
    }

    var recurrence: DateRecurrence {
        get { DateRecurrence(rawValue: recurrenceRaw) ?? .oneTime }
        set { recurrenceRaw = newValue.rawValue }
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .localOnly }
        set { syncStatusRaw = newValue.rawValue }
    }

    var displayLabel: String {
        if let label, !label.isEmpty { return label }
        return "Remind me around this date"
    }

    func touch(_ date: Date = .now) {
        updatedAt = date
    }

    /// Next fire date at or after `from`, respecting recurrence.
    func nextOccurrence(from reference: Date = .now, calendar: Calendar = .current) -> Date? {
        guard enabled else { return nil }

        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = reminderHour
        components.minute = reminderMinute
        components.second = 0

        switch recurrence {
        case .oneTime:
            guard let candidate = calendar.date(from: components) else { return nil }
            return candidate >= reference ? candidate : nil
        case .yearly:
            let nowComponents = calendar.dateComponents([.year], from: reference)
            components.year = nowComponents.year
            guard var candidate = calendar.date(from: components) else { return nil }
            if candidate < reference {
                guard let nextYear = calendar.date(byAdding: .year, value: 1, to: candidate) else {
                    return nil
                }
                candidate = nextYear
            }
            return candidate
        }
    }
}
