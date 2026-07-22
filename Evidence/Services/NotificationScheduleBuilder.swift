import Foundation

/// Pure notification schedule helpers (identifiers, weekdays, preview copy).
enum NotificationScheduleBuilder {
    static let identifierPrefix = "evidence."
    static let defaultBody = "A reminder from your collection is ready."

    /// Builds a repeating weekly notification identifier.
    static func weeklyIdentifier(weekday: Int, hour: Int, minute: Int) -> String {
        "\(identifierPrefix)weekly.\(weekday).\(hour).\(minute)"
    }

    /// One scheduled slot per weekday.
    struct ScheduleSlot: Equatable, Sendable {
        var identifier: String
        var weekday: Int
        var hour: Int
        var minute: Int
    }

    /// Generates schedule slots from weekdays and delivery time.
    static func scheduleSlots(
        weekdays: [Int],
        hour: Int,
        minute: Int
    ) -> [ScheduleSlot] {
        let clampedHour = min(23, max(0, hour))
        let clampedMinute = min(59, max(0, minute))
        return weekdays.map { weekday in
            ScheduleSlot(
                identifier: weeklyIdentifier(weekday: weekday, hour: clampedHour, minute: clampedMinute),
                weekday: weekday,
                hour: clampedHour,
                minute: clampedMinute
            )
        }
    }

    /// Preview title/body for a notification, respecting privacy mode.
    struct PreviewContent: Equatable, Sendable {
        var title: String
        var body: String
    }

    static func previewContent(
        mode: NotificationPreviewMode,
        entryTitle: String?,
        entryBody: String?,
        meaningPromptAnswer: String?,
        genericPreviewOnly: Bool
    ) -> PreviewContent {
        let effectiveMode: NotificationPreviewMode = genericPreviewOnly ? .generic : mode
        switch effectiveMode {
        case .generic:
            return PreviewContent(title: "Evidence", body: defaultBody)
        case .titleOnly:
            return PreviewContent(
                title: "Evidence",
                body: nonEmpty(entryTitle) ?? defaultBody
            )
        case .fullContent:
            let title = nonEmpty(entryTitle) ?? "Evidence"
            if let body = nonEmpty(entryBody) {
                return PreviewContent(title: title, body: body)
            }
            if let meaning = nonEmpty(meaningPromptAnswer) {
                return PreviewContent(title: title, body: meaning)
            }
            return PreviewContent(title: title, body: defaultBody)
        }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
