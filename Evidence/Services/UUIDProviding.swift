import Foundation

/// Abstraction over UUID generation for deterministic tests.
protocol UUIDProviding: Sendable {
    func makeUUID() -> UUID
}

/// Uses `UUID()` from the system.
struct SystemUUIDProvider: UUIDProviding {
    func makeUUID() -> UUID { UUID() }
}

/// Returns a predetermined sequence of UUIDs, then falls back to system UUIDs.
/// Intended for unit tests and preview fixtures.
final class FixedUUIDProvider: UUIDProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var remaining: [UUID]
    private let fallback: UUIDProviding

    init(uuids: [UUID], fallback: UUIDProviding = SystemUUIDProvider()) {
        self.remaining = uuids
        self.fallback = fallback
    }

    func makeUUID() -> UUID {
        lock.lock()
        defer { lock.unlock() }
        if remaining.isEmpty {
            return fallback.makeUUID()
        }
        return remaining.removeFirst()
    }
}
