import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @Environment(AppContainer.self) private var container
    var onFinished: (() -> Void)? = nil

    @State private var viewModel = AuthenticationViewModel()
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.md) {
                    SectionHeader(
                        title: String(localized: "auth.title", defaultValue: "Sign in for private sync"),
                        subtitle: String(
                            localized: "auth.subtitle",
                            defaultValue: "Your collection stays on this device until you choose to sync."
                        )
                    )

                    AuthenticationStatusView(
                        isAuthenticated: container.authentication.isAuthenticated,
                        cloudSyncEnabled: viewModel.cloudSyncEnabled
                    )

                    SignInWithAppleButton(.signIn) { request in
                        viewModel.prepareAppleRequest(request)
                    } onCompletion: { result in
                        Task { await viewModel.handleAppleCompletion(result, container: container) }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: EvidenceTheme.minTouchTarget)
                    .accessibilityLabel(String(localized: "auth.apple", defaultValue: "Sign in with Apple"))

                    SecondaryButton(
                        title: String(localized: "auth.magicLink", defaultValue: "Continue with email magic link")
                    ) {
                        path.append(AppRoute.magicLink)
                    }

                    if container.authentication.isAuthenticated {
                        PrimaryButton(
                            title: String(localized: "auth.continue", defaultValue: "Continue")
                        ) {
                            if viewModel.shouldOfferMigration {
                                path.append(AppRoute.localToCloudMigration)
                            } else {
                                onFinished?()
                            }
                        }

                        SecondaryButton(
                            title: String(localized: "auth.signOut", defaultValue: "Sign out")
                        ) {
                            Task { await viewModel.signOut(container: container) }
                        }
                    } else {
                        SecondaryButton(
                            title: String(localized: "auth.stayLocal", defaultValue: "Stay local-only")
                        ) {
                            onFinished?()
                        }
                    }

                    if let message = viewModel.statusMessage {
                        Text(message)
                            .font(.evidenceCaption())
                            .foregroundStyle(EvidenceFallbackColors.muted)
                    }

                    PrivacyNoticeView()
                }
                .padding(EvidenceTheme.Spacing.lg)
            }
            .navigationTitle(String(localized: "auth.nav", defaultValue: "Account"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .magicLink:
                    MagicLinkView {
                        path.removeLast()
                        Task { await viewModel.refreshAfterAuth(container: container) }
                    }
                case .localToCloudMigration:
                    LocalToCloudMigrationView {
                        onFinished?()
                    }
                default:
                    EmptyView()
                }
            }
            .task {
                await viewModel.refreshAfterAuth(container: container)
            }
        }
    }
}

@Observable
@MainActor
final class AuthenticationViewModel {
    var statusMessage: String?
    var cloudSyncEnabled = false
    var shouldOfferMigration = false
    private var appleNonce: String?

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonce()
        appleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = nonce
    }

    func handleAppleCompletion(
        _ result: Result<ASAuthorization, Error>,
        container: AppContainer
    ) async {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled {
                statusMessage = nil
            } else {
                statusMessage = String(
                    localized: "auth.appleFailed",
                    defaultValue: "Sign in with Apple could not finish. You can try email or stay local-only."
                )
            }
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else {
                statusMessage = String(
                    localized: "auth.appleInvalid",
                    defaultValue: "Apple sign-in did not return a usable credential."
                )
                return
            }
            do {
                try await container.authentication.signInWithApple(idToken: idToken, nonce: appleNonce)
                await afterSuccessfulSignIn(container: container)
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func signOut(container: AppContainer) async {
        do {
            try await container.authentication.signOut()
            let profile = await container.ensureProfile()
            profile.authenticatedUserID = nil
            profile.cloudSyncEnabled = false
            profile.touch()
            try? await container.profileRepository.save(profile)
            cloudSyncEnabled = false
            statusMessage = String(localized: "auth.signedOut", defaultValue: "Signed out. Local data remains on this device.")
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func refreshAfterAuth(container: AppContainer) async {
        let profile = await container.ensureProfile()
        cloudSyncEnabled = profile.cloudSyncEnabled
        if container.authentication.isAuthenticated {
            await afterSuccessfulSignIn(container: container)
        }
    }

    private func afterSuccessfulSignIn(container: AppContainer) async {
        let profile = await container.ensureProfile()
        profile.authenticatedUserID = container.authentication.currentUserID
        profile.touch()
        try? await container.profileRepository.save(profile)
        let entries = (try? await container.entryRepository.fetchAll(includeArchived: true)) ?? []
        shouldOfferMigration = !entries.isEmpty && !profile.cloudSyncEnabled
        statusMessage = String(localized: "auth.success", defaultValue: "Signed in.")
    }

    private func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        result.reserveCapacity(length)
        for _ in 0..<length {
            result.append(charset[Int.random(in: 0..<charset.count)])
        }
        return result
    }
}

struct MagicLinkView: View {
    @Environment(AppContainer.self) private var container
    var onSent: (() -> Void)? = nil

    @State private var email = ""
    @State private var isSending = false
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                TextField(
                    String(localized: "auth.email", defaultValue: "Email"),
                    text: $email
                )
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            } header: {
                Text(String(localized: "auth.magic.title", defaultValue: "Email magic link"))
            } footer: {
                Text(
                    String(
                        localized: "auth.magic.footer",
                        defaultValue: "We’ll email a sign-in link. Evidence does not require a password."
                    )
                )
            }

            if let message {
                Section {
                    Text(message)
                        .font(.evidenceCaption())
                        .foregroundStyle(EvidenceFallbackColors.muted)
                }
            }

            Section {
                PrimaryButton(
                    title: String(localized: "auth.magic.send", defaultValue: "Send magic link"),
                    isEnabled: isValidEmail,
                    isLoading: isSending
                ) {
                    Task { await send() }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(String(localized: "auth.magic.nav", defaultValue: "Email"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isValidEmail: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") && trimmed.contains(".")
    }

    private func send() async {
        isSending = true
        defer { isSending = false }
        do {
            try await container.authentication.signInWithMagicLink(email: email)
            message = String(
                localized: "auth.magic.sent",
                defaultValue: "Check your email for a sign-in link. You can close this screen."
            )
            onSent?()
        } catch {
            message = error.localizedDescription
        }
    }
}

struct LocalToCloudMigrationView: View {
    @Environment(AppContainer.self) private var container
    var onFinished: (() -> Void)? = nil

    @State private var confirmSensitive = false
    @State private var isMigrating = false
    @State private var progressMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.md) {
                SectionHeader(
                    title: String(localized: "migration.title", defaultValue: "Upload your collection?"),
                    subtitle: String(
                        localized: "migration.body",
                        defaultValue: "Local entries can be uploaded to your private account. Nothing is erased if upload fails."
                    )
                )

                Toggle(
                    String(
                        localized: "migration.confirmSensitive",
                        defaultValue: "I understand sensitive entries will be included"
                    ),
                    isOn: $confirmSensitive
                )
                .tint(EvidenceFallbackColors.accent)

                if let progressMessage {
                    Text(progressMessage)
                        .font(.evidenceCaption())
                        .foregroundStyle(EvidenceFallbackColors.muted)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.evidenceCaption())
                        .foregroundStyle(.orange)
                }

                PrimaryButton(
                    title: String(localized: "migration.upload", defaultValue: "Upload to my account"),
                    isEnabled: confirmSensitive,
                    isLoading: isMigrating
                ) {
                    Task { await migrate() }
                }

                SecondaryButton(
                    title: String(localized: "migration.later", defaultValue: "Not now")
                ) {
                    onFinished?()
                }

                PrivacyNoticeView()
            }
            .padding(EvidenceTheme.Spacing.lg)
        }
        .navigationTitle(String(localized: "migration.nav", defaultValue: "Migration"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func migrate() async {
        isMigrating = true
        errorMessage = nil
        defer { isMigrating = false }

        guard let userID = container.authentication.currentUserID else {
            errorMessage = String(localized: "migration.noUser", defaultValue: "Sign in before uploading.")
            return
        }

        do {
            let entries = try await container.entryRepository.fetchAll(includeArchived: true)
            progressMessage = String(
                localized: "migration.progress",
                defaultValue: "Preparing \(entries.count) entries…"
            )
            for entry in entries {
                entry.ownerUserID = userID
                if entry.syncStatus == .localOnly {
                    entry.markPendingUpload()
                }
                try await container.entryRepository.save(entry)
            }

            let profile = await container.ensureProfile()
            profile.cloudSyncEnabled = true
            profile.authenticatedUserID = userID
            profile.touch()
            try await container.profileRepository.save(profile)

            progressMessage = String(localized: "migration.syncing", defaultValue: "Syncing…")
            await container.syncCoordinator.syncNow()

            if let syncError = container.syncCoordinator.lastErrorMessage {
                errorMessage = syncError
                progressMessage = String(
                    localized: "migration.partial",
                    defaultValue: "Local data is safe. You can retry sync from Settings."
                )
            } else {
                progressMessage = String(localized: "migration.done", defaultValue: "Upload finished.")
                onFinished?()
            }
        } catch {
            errorMessage = String(
                localized: "migration.failed",
                defaultValue: "Upload could not finish. Your local collection is still available."
            )
        }
    }
}
