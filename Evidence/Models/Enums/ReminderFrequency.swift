import Foundation

enum ReminderFrequency: String, Codable, CaseIterable, Identifiable, Sendable {
    case daily
    case weekdays
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily:
            return "Daily"
        case .weekdays:
            return "Weekdays"
        case .custom:
            return "Custom"
        }
    }

    /// Calendar weekday numbers (1 = Sunday … 7 = Saturday) implied by this frequency.
    func defaultWeekdays(custom: [Int] = []) -> [Int] {
        switch self {
        case .daily:
            return [1, 2, 3, 4, 5, 6, 7]
        case .weekdays:
            return [2, 3, 4, 5, 6]
        case .custom:
            return custom
        }
    }
}
