import Foundation

/// Abstraction over the current date for deterministic tests and sync logic.
protocol DateProviding: Sendable {
    var now: Date { get }
}

/// Returns the system clock.
struct SystemDateProvider: DateProviding {
    var now: Date { Date() }
}

/// Returns a fixed instant — intended for unit tests and previews.
struct FixedDateProvider: DateProviding {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}
