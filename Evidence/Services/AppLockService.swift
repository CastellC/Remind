import Foundation
import LocalAuthentication
import UIKit

/// Device-owner authentication and privacy cover for Evidence.
@MainActor
protocol AppLockServing: AnyObject {
    var isLockEnabled: Bool { get set }
    var isLocked: Bool { get }
    var shouldShowPrivacyCover: Bool { get }
    var biometricDisplayName: String { get }

    func applicationDidEnterBackground()
    func applicationWillEnterForeground() async
    func unlock() async -> Bool
    func canUseBiometrics() -> Bool
}

enum AppLockError: Error, LocalizedError, Sendable {
    case cancelled
    case failed
    case unavailable

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Authentication was cancelled."
        case .failed:
            return "Authentication failed."
        case .unavailable:
            return "Device authentication is unavailable."
        }
    }
}

@MainActor
final class AppLockService: AppLockServing {
    /// Seconds in background before the app requires unlock again.
    var backgroundLockInterval: TimeInterval

    var isLockEnabled: Bool {
        didSet { persistEnabled() }
    }

    private(set) var isLocked: Bool = false
    private(set) var shouldShowPrivacyCover: Bool = false

    private var backgroundedAt: Date?
    private let dateProvider: any DateProviding
    private let contextFactory: () -> LAContext
    private let defaults: UserDefaults
    private let enabledKey = "evidence.appLock.enabled"

    init(
        isLockEnabled: Bool? = nil,
        backgroundLockInterval: TimeInterval = 30,
        dateProvider: any DateProviding = SystemDateProvider(),
        contextFactory: @escaping () -> LAContext = { LAContext() },
        defaults: UserDefaults = .standard
    ) {
        self.backgroundLockInterval = backgroundLockInterval
        self.dateProvider = dateProvider
        self.contextFactory = contextFactory
        self.defaults = defaults
        if let isLockEnabled {
            self.isLockEnabled = isLockEnabled
        } else {
            self.isLockEnabled = defaults.bool(forKey: enabledKey)
        }
        if self.isLockEnabled {
            self.isLocked = true
        }
    }

    var biometricDisplayName: String {
        let context = contextFactory()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "Device passcode"
        }
        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        @unknown default:
            return "Device authentication"
        }
    }

    func canUseBiometrics() -> Bool {
        let context = contextFactory()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    func applicationDidEnterBackground() {
        guard isLockEnabled else {
            shouldShowPrivacyCover = false
            return
        }
        shouldShowPrivacyCover = true
        backgroundedAt = dateProvider.now
    }

    func applicationWillEnterForeground() async {
        shouldShowPrivacyCover = false
        guard isLockEnabled else {
            isLocked = false
            return
        }
        let now = dateProvider.now
        if let backgroundedAt,
           now.timeIntervalSince(backgroundedAt) >= backgroundLockInterval {
            isLocked = true
        } else if backgroundedAt == nil {
            isLocked = true
        }
        backgroundedAt = nil
    }

    @discardableResult
    func unlock() async -> Bool {
        guard isLockEnabled else {
            isLocked = false
            return true
        }
        let context = contextFactory()
        let reason = "Unlock Evidence to view your private collection."
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            isLocked = !success
            return success
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel, .systemCancel:
                return false
            default:
                return false
            }
        } catch {
            return false
        }
    }

    private func persistEnabled() {
        defaults.set(isLockEnabled, forKey: enabledKey)
        if !isLockEnabled {
            isLocked = false
            shouldShowPrivacyCover = false
        } else {
            isLocked = true
        }
    }
}

/// Preview / test double.
@MainActor
final class MockAppLockService: AppLockServing {
    var isLockEnabled: Bool
    var isLocked: Bool
    var shouldShowPrivacyCover: Bool = false
    var biometricDisplayName: String = "Face ID"
    var unlockSucceeds = true

    init(isLockEnabled: Bool = false, isLocked: Bool = false) {
        self.isLockEnabled = isLockEnabled
        self.isLocked = isLocked
    }

    func applicationDidEnterBackground() {
        shouldShowPrivacyCover = isLockEnabled
    }

    func applicationWillEnterForeground() async {
        shouldShowPrivacyCover = false
        if isLockEnabled { isLocked = true }
    }

    func unlock() async -> Bool {
        guard unlockSucceeds else { return false }
        isLocked = false
        return true
    }

    func canUseBiometrics() -> Bool { true }
}
