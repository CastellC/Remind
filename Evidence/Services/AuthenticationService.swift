import Foundation
import AuthenticationServices

#if canImport(Supabase)
import Supabase
#endif

/// Authentication surface for Evidence.
@MainActor
protocol AuthenticationServing: AnyObject {
    var currentUserID: UUID? { get }
    var isAuthenticated: Bool { get }

    func restoreSession() async throws
    func signInWithApple(idToken: String, nonce: String?) async throws
    func signInWithMagicLink(email: String) async throws
    func signOut() async throws
    func deleteAccount() async throws
}

enum AuthenticationError: Error, LocalizedError, Sendable {
    case notConfigured
    case invalidCredentials
    case sessionMissing
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Cloud sign-in is not configured on this device."
        case .invalidCredentials:
            return "Sign-in could not be completed."
        case .sessionMissing:
            return "No active session."
        case .underlying(let message):
            return message
        }
    }
}

// MARK: - Supabase implementation

#if canImport(Supabase)
@MainActor
final class SupabaseAuthenticationService: AuthenticationServing {
    private let client: SupabaseClient
    private let keychainService: String
    private let sessionAccount = "supabase.session"

    private(set) var currentUserID: UUID?
    var isAuthenticated: Bool { currentUserID != nil }

    init(client: SupabaseClient, keychainService: String = "com.evidence.app.auth") {
        self.client = client
        self.keychainService = keychainService
    }

    func restoreSession() async throws {
        do {
            let session = try await client.auth.session
            currentUserID = UUID(uuidString: session.user.id.uuidString) ?? session.user.id
            try persistSessionHint(userID: currentUserID)
        } catch {
            currentUserID = nil
            // Missing session is not fatal for local-only use.
        }
    }

    func signInWithApple(idToken: String, nonce: String?) async throws {
        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        currentUserID = session.user.id
        try persistSessionHint(userID: currentUserID)
    }

    func signInWithMagicLink(email: String) async throws {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AuthenticationError.invalidCredentials }
        try await client.auth.signInWithOTP(email: trimmed)
    }

    func signOut() async throws {
        try await client.auth.signOut()
        currentUserID = nil
        try KeychainHelper.delete(service: keychainService, account: sessionAccount)
    }

    func deleteAccount() async throws {
        // Account deletion requires a server-side RPC / Edge Function with service role.
        // Call a documented RPC when available; otherwise surface a clear error.
        do {
            try await client.rpc("delete_user_account").execute()
            try await signOut()
        } catch {
            throw AuthenticationError.underlying(
                "Account deletion could not be completed. Try again or contact support."
            )
        }
    }

    private func persistSessionHint(userID: UUID?) throws {
        guard let userID else {
            try KeychainHelper.delete(service: keychainService, account: sessionAccount)
            return
        }
        // Store only the user ID hint — session tokens remain in Supabase SDK storage.
        try KeychainHelper.set(userID.uuidString, service: keychainService, account: sessionAccount)
    }
}
#endif

// MARK: - Unconfigured / mock

/// Used when Supabase URL/key are missing. Local features remain available.
@MainActor
final class UnavailableAuthenticationService: AuthenticationServing {
    var currentUserID: UUID? { nil }
    var isAuthenticated: Bool { false }

    func restoreSession() async throws {}

    func signInWithApple(idToken: String, nonce: String?) async throws {
        throw AuthenticationError.notConfigured
    }

    func signInWithMagicLink(email: String) async throws {
        throw AuthenticationError.notConfigured
    }

    func signOut() async throws {}

    func deleteAccount() async throws {
        throw AuthenticationError.notConfigured
    }
}

/// In-memory auth for tests and SwiftUI previews.
@MainActor
final class MockAuthenticationService: AuthenticationServing {
    private(set) var currentUserID: UUID?
    var isAuthenticated: Bool { currentUserID != nil }
    var magicLinkEmails: [String] = []
    var didDeleteAccount = false

    init(currentUserID: UUID? = nil) {
        self.currentUserID = currentUserID
    }

    func restoreSession() async throws {}

    func signInWithApple(idToken: String, nonce: String?) async throws {
        guard !idToken.isEmpty else { throw AuthenticationError.invalidCredentials }
        currentUserID = UUID()
    }

    func signInWithMagicLink(email: String) async throws {
        magicLinkEmails.append(email)
    }

    func signOut() async throws {
        currentUserID = nil
    }

    func deleteAccount() async throws {
        didDeleteAccount = true
        currentUserID = nil
    }
}
