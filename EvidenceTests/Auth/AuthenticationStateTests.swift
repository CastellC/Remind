import XCTest
import SwiftData
@testable import Evidence

@MainActor
final class AuthenticationStateTests: XCTestCase {
    func testMockSignInAndSignOut() async throws {
        let auth = MockAuthenticationService()
        XCTAssertFalse(auth.isAuthenticated)
        XCTAssertNil(auth.currentUserID)

        try await auth.signInWithApple(idToken: "valid-token", nonce: "nonce")
        XCTAssertTrue(auth.isAuthenticated)
        XCTAssertNotNil(auth.currentUserID)

        try await auth.signOut()
        XCTAssertFalse(auth.isAuthenticated)
        XCTAssertNil(auth.currentUserID)
    }

    func testSignInWithEmptyTokenFails() async {
        let auth = MockAuthenticationService()
        do {
            try await auth.signInWithApple(idToken: "", nonce: nil)
            XCTFail("Expected invalid credentials")
        } catch {
            XCTAssertTrue(error is AuthenticationError)
        }
    }

    func testRestoreSessionDoesNotClearConfiguredUser() async throws {
        let userID = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!
        let auth = MockAuthenticationService(currentUserID: userID)
        try await auth.restoreSession()
        XCTAssertEqual(auth.currentUserID, userID)
        XCTAssertTrue(auth.isAuthenticated)
    }

    func testSignOutPreservesLocalEvidenceData() async throws {
        let container = try ModelContainer.evidence(inMemory: true)
        let context = ModelContext(container)
        let repos = LocalRepositoryBundle(context: context)

        let entry = EvidenceEntry(
            title: "Local reminder",
            bodyText: "Stays on device",
            meaningPromptAnswer: "Someone believed in me"
        )
        try await repos.entries.save(entry)

        let userID = UUID()
        let auth = MockAuthenticationService(currentUserID: userID)
        XCTAssertTrue(auth.isAuthenticated)

        try await auth.signOut()
        XCTAssertFalse(auth.isAuthenticated)

        let remaining = try await repos.entries.fetchAll(includeArchived: true)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.title, "Local reminder")
    }

    func testDeleteAccountClearsAuthButLocalDeleteIsSeparate() async throws {
        let container = try ModelContainer.evidence(inMemory: true)
        let context = ModelContext(container)
        let repos = LocalRepositoryBundle(context: context)

        try await repos.entries.save(
            EvidenceEntry(title: "Keep until deleted", meaningPromptAnswer: "Meaning")
        )

        let auth = MockAuthenticationService(currentUserID: UUID())
        try await auth.deleteAccount()
        XCTAssertTrue(auth.didDeleteAccount)
        XCTAssertNil(auth.currentUserID)

        // Conceptual: auth deletion alone does not wipe local SwiftData.
        let remaining = try await repos.entries.fetchAll(includeArchived: true)
        XCTAssertEqual(remaining.count, 1)
    }

    func testMagicLinkRecordsEmail() async throws {
        let auth = MockAuthenticationService()
        try await auth.signInWithMagicLink(email: "person@example.com")
        XCTAssertEqual(auth.magicLinkEmails, ["person@example.com"])
    }

    func testUnavailableAuthRejectsCloudSignIn() async {
        let auth = UnavailableAuthenticationService()
        XCTAssertFalse(auth.isAuthenticated)
        do {
            try await auth.signInWithApple(idToken: "token", nonce: nil)
            XCTFail("Expected notConfigured")
        } catch let error as AuthenticationError {
            XCTAssertEqual(error, .notConfigured)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
