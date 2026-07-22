import XCTest
@testable import Evidence

final class NotificationScheduleTests: XCTestCase {
    func testIdentifierPrefix() {
        XCTAssertEqual(NotificationScheduleBuilder.identifierPrefix, "evidence.")
        XCTAssertEqual(
            LocalNotificationService.identifierPrefix,
            NotificationScheduleBuilder.identifierPrefix
        )
    }

    func testWeeklyIdentifierFormat() {
        let id = NotificationScheduleBuilder.weeklyIdentifier(weekday: 2, hour: 9, minute: 30)
        XCTAssertEqual(id, "evidence.weekly.2.9.30")
        XCTAssertTrue(id.hasPrefix(NotificationScheduleBuilder.identifierPrefix))
    }

    func testScheduleGenerationForWeekdays() {
        let slots = NotificationScheduleBuilder.scheduleSlots(
            weekdays: [2, 3, 4, 5, 6],
            hour: 9,
            minute: 0
        )

        XCTAssertEqual(slots.count, 5)
        XCTAssertEqual(slots.map(\.weekday), [2, 3, 4, 5, 6])
        XCTAssertTrue(slots.allSatisfy { $0.hour == 9 && $0.minute == 0 })
        XCTAssertTrue(slots.allSatisfy { $0.identifier.hasPrefix("evidence.weekly.") })
    }

    func testScheduleClampsHourAndMinute() {
        let slots = NotificationScheduleBuilder.scheduleSlots(
            weekdays: [1],
            hour: 99,
            minute: -5
        )
        XCTAssertEqual(slots.first?.hour, 23)
        XCTAssertEqual(slots.first?.minute, 0)
    }

    func testReminderScheduleEffectiveWeekdays() {
        let daily = ReminderSchedule(isEnabled: true, frequency: .daily)
        XCTAssertEqual(daily.effectiveWeekdays, [1, 2, 3, 4, 5, 6, 7])

        let weekdays = ReminderSchedule(isEnabled: true, frequency: .weekdays)
        XCTAssertEqual(weekdays.effectiveWeekdays, [2, 3, 4, 5, 6])

        let custom = ReminderSchedule(
            isEnabled: true,
            selectedWeekdays: [1, 7],
            frequency: .custom
        )
        XCTAssertEqual(custom.effectiveWeekdays, [1, 7])
    }

    // MARK: - Preview modes

    func testGenericPreviewMode() {
        let content = NotificationScheduleBuilder.previewContent(
            mode: .generic,
            entryTitle: "Private title",
            entryBody: "Private body",
            meaningPromptAnswer: "Meaning",
            genericPreviewOnly: false
        )
        XCTAssertEqual(content.title, "Evidence")
        XCTAssertEqual(content.body, NotificationScheduleBuilder.defaultBody)
    }

    func testTitleOnlyPreviewMode() {
        let content = NotificationScheduleBuilder.previewContent(
            mode: .titleOnly,
            entryTitle: "You are capable",
            entryBody: "Long body",
            meaningPromptAnswer: "Meaning",
            genericPreviewOnly: false
        )
        XCTAssertEqual(content.title, "Evidence")
        XCTAssertEqual(content.body, "You are capable")
    }

    func testFullContentPreviewPrefersBodyThenMeaning() {
        let withBody = NotificationScheduleBuilder.previewContent(
            mode: .fullContent,
            entryTitle: "Title",
            entryBody: "Body text",
            meaningPromptAnswer: "Meaning",
            genericPreviewOnly: false
        )
        XCTAssertEqual(withBody.title, "Title")
        XCTAssertEqual(withBody.body, "Body text")

        let withMeaning = NotificationScheduleBuilder.previewContent(
            mode: .fullContent,
            entryTitle: "Title",
            entryBody: "  ",
            meaningPromptAnswer: "Someone believed in me",
            genericPreviewOnly: false
        )
        XCTAssertEqual(withMeaning.body, "Someone believed in me")
    }

    func testGenericPreviewOnlyOverridesMode() {
        let content = NotificationScheduleBuilder.previewContent(
            mode: .fullContent,
            entryTitle: "Secret",
            entryBody: "Should not appear",
            meaningPromptAnswer: nil,
            genericPreviewOnly: true
        )
        XCTAssertEqual(content.title, "Evidence")
        XCTAssertEqual(content.body, NotificationScheduleBuilder.defaultBody)
    }

    @MainActor
    func testMockNotificationServiceScheduleCount() async throws {
        let service = MockNotificationService()
        service.authorizationGranted = true

        let schedule = ReminderSchedule(
            isEnabled: true,
            frequency: .weekdays,
            deliveryHour: 8,
            deliveryMinute: 15
        )

        try await service.reschedule(from: schedule, entries: [], previewMode: .generic)
        XCTAssertEqual(service.scheduledCount, schedule.effectiveWeekdays.count)

        schedule.isEnabled = false
        try await service.reschedule(from: schedule, entries: [], previewMode: .generic)
        XCTAssertEqual(service.scheduledCount, 0)
    }
}
