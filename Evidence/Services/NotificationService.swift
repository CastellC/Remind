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
    static let identifierPrefix = "evidence."
    static let defaultBody = "A reminder from your collection is ready."

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

        let weekdays = schedule.effectiveWeekdays
        guard !weekdays.isEmpty else { return }

        // Schedule one request per weekday for the next cycle.
        for weekday in weekdays {
            let identifier = "\(Self.identifierPrefix)weekly.\(weekday).\(schedule.deliveryHour).\(schedule.deliveryMinute)"
            var dateComponents = DateComponents()
            dateComponents.weekday = weekday
            dateComponents.hour = schedule.deliveryHour
            dateComponents.minute = schedule.deliveryMinute

            let content = UNMutableNotificationContent()
            content.sound = .default

            let sample = eligible.randomElement()
            let effectivePreview: NotificationPreviewMode =
                schedule.genericPreviewOnly ? .generic : previewMode

            switch effectivePreview {
            case .generic:
                content.title = "Evidence"
                content.body = Self.defaultBody
            case .titleOnly:
                content.title = "Evidence"
                content.body = sample?.title ?? Self.defaultBody
            case .fullContent:
                content.title = sample?.title ?? "Evidence"
                if let body = sample?.bodyText, !body.isEmpty {
                    content.body = body
                } else if let meaning = sample?.meaningPromptAnswer, !meaning.isEmpty {
                    content.body = meaning
                } else {
                    content.body = Self.defaultBody
                }
            }

            if let sample {
                content.userInfo = ["entryID": sample.id.uuidString]
            }

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
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
