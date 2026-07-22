import Foundation
import UserNotifications

/// Schedules and cancels local reminders for Evidence.
@MainActor
protocol NotificationServing: AnyObject {
    func requestAuthorization() async throws -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func reschedule(from schedule: ReminderSchedule, entries: [EvidenceEntry], previewMode: NotificationPreviewMode) async throws
    func cancelAllEvidenceNotifications() async
    func cancelNotifications(matchingPrefix prefix: String) async
}

enum NotificationServiceError: Error, LocalizedError, Sendable {
    case authorizationDenied

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Notifications are turned off for Evidence. You can enable them in Settings."
        }
    }
}

/// Local notification scheduling via UserNotifications.
/// Authorization is requested only when `requestAuthorization()` is called explicitly.
@MainActor
final class LocalNotificationService: NotificationServing {
    static let identifierPrefix = NotificationScheduleBuilder.identifierPrefix
    static let defaultBody = NotificationScheduleBuilder.defaultBody

    private let center: UNUserNotificationCenter
    private let dateProvider: any DateProviding

    init(
        center: UNUserNotificationCenter = .current(),
        dateProvider: any DateProviding = SystemDateProvider()
    ) {
        self.center = center
        self.dateProvider = dateProvider
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    func reschedule(
        from schedule: ReminderSchedule,
        entries: [EvidenceEntry],
        previewMode: NotificationPreviewMode
    ) async throws {
        await cancelAllEvidenceNotifications()

        guard schedule.isEnabled else { return }

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else {
            return
        }

        let eligible = entries.filter { entry in
            guard entry.isEligibleForNotification else { return false }
            if schedule.allowsAllCategories { return true }
            let categoryIDs = Set(entry.categories.map(\.id))
            return !categoryIDs.isDisjoint(with: Set(schedule.allowedCategoryIDs))
        }

        let slots = NotificationScheduleBuilder.scheduleSlots(
            weekdays: schedule.effectiveWeekdays,
            hour: schedule.deliveryHour,
            minute: schedule.deliveryMinute
        )
        guard !slots.isEmpty else { return }

        for slot in slots {
            var dateComponents = DateComponents()
            dateComponents.weekday = slot.weekday
            dateComponents.hour = slot.hour
            dateComponents.minute = slot.minute

            let content = UNMutableNotificationContent()
            content.sound = .default

            let sample = eligible.randomElement()
            let preview = NotificationScheduleBuilder.previewContent(
                mode: previewMode,
                entryTitle: sample?.title,
                entryBody: sample?.bodyText,
                meaningPromptAnswer: sample?.meaningPromptAnswer,
                genericPreviewOnly: schedule.genericPreviewOnly
            )
            content.title = preview.title
            content.body = preview.body

            if let sample {
                content.userInfo = ["entryID": sample.id.uuidString]
            }

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: slot.identifier, content: content, trigger: trigger)
            try await center.add(request)
        }

        schedule.lastScheduledAt = dateProvider.now
    }

    func cancelAllEvidenceNotifications() async {
        await cancelNotifications(matchingPrefix: Self.identifierPrefix)
    }

    func cancelNotifications(matchingPrefix prefix: String) async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }
}

/// No-op notifications for previews and tests.
@MainActor
final class MockNotificationService: NotificationServing {
    var authorizationGranted = false
    var scheduledCount = 0

    func requestAuthorization() async throws -> Bool {
        authorizationGranted = true
        return true
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        authorizationGranted ? .authorized : .notDetermined
    }

    func reschedule(from schedule: ReminderSchedule, entries: [EvidenceEntry], previewMode: NotificationPreviewMode) async throws {
        scheduledCount = schedule.isEnabled ? schedule.effectiveWeekdays.count : 0
    }

    func cancelAllEvidenceNotifications() async {
        scheduledCount = 0
    }

    func cancelNotifications(matchingPrefix prefix: String) async {
        scheduledCount = 0
    }
}
