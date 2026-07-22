import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppContainer.self) private var container
    @Query private var profiles: [AppProfile]
    @State private var path = NavigationPath()
    @State private var confirmReplay = false

    private var profile: AppProfile? { profiles.first }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    AuthenticationStatusView(
                        isAuthenticated: container.authentication.isAuthenticated,
                        cloudSyncEnabled: profile?.cloudSyncEnabled ?? false
                    )
                    .listRowBackground(Color(.secondarySystemBackground))
                }

                Section(String(localized: "settings.account", defaultValue: "Account and sync")) {
                    NavigationLink(value: AppRoute.syncSettings) {
                        Label(String(localized: "settings.sync", defaultValue: "Account and sync"), systemImage: "arrow.triangle.2.circlepath")
                    }
                    NavigationLink(value: AppRoute.authentication) {
                        Label(String(localized: "settings.signIn", defaultValue: "Sign in"), systemImage: "person.crop.circle")
                    }
                }

                Section(String(localized: "settings.privacySecurity", defaultValue: "Privacy and security")) {
                    NavigationLink(value: AppRoute.appLockSettings) {
                        Label(String(localized: "settings.appLock", defaultValue: "App lock"), systemImage: "lock")
                    }
                    NavigationLink(value: AppRoute.privacy) {
                        Label(String(localized: "settings.privacy", defaultValue: "Privacy"), systemImage: "hand.raised")
                    }
                    NavigationLink(value: AppRoute.safetyInformation) {
                        Label(String(localized: "settings.safety", defaultValue: "Safety and support"), systemImage: "lifepreserver")
                    }
                    NavigationLink(value: AppRoute.accessibilityStatement) {
                        Label(String(localized: "settings.a11y", defaultValue: "Accessibility statement"), systemImage: "accessibility")
                    }
                }

                Section(String(localized: "settings.reminders", defaultValue: "Reminders")) {
                    NavigationLink(value: AppRoute.notificationSettings) {
                        Label(String(localized: "settings.notifications", defaultValue: "Notification preferences"), systemImage: "bell")
                    }
                    NavigationLink(value: AppRoute.meaningfulDateSettings) {
                        Label(String(localized: "settings.meaningfulDates", defaultValue: "Meaningful dates"), systemImage: "calendar")
                    }
                }

                Section(String(localized: "settings.data", defaultValue: "Your data")) {
                    NavigationLink(value: AppRoute.export) {
                        Label(String(localized: "settings.export", defaultValue: "Export"), systemImage: "square.and.arrow.up")
                    }
                    NavigationLink(value: AppRoute.deleteData) {
                        Label(String(localized: "settings.deleteData", defaultValue: "Delete data"), systemImage: "trash")
                    }
                    NavigationLink(value: AppRoute.deleteAccount) {
                        Label(String(localized: "settings.deleteAccount", defaultValue: "Delete account"), systemImage: "person.crop.circle.badge.minus")
                    }
                    NavigationLink(value: AppRoute.categoryManager) {
                        Label(String(localized: "settings.categories", defaultValue: "Categories"), systemImage: "folder")
                    }
                }

                Section(String(localized: "settings.aboutSection", defaultValue: "About")) {
                    NavigationLink(value: AppRoute.about) {
                        Label(String(localized: "settings.about", defaultValue: "About"), systemImage: "info.circle")
                    }
                    NavigationLink(value: AppRoute.howEvidenceWorks) {
                        Label(String(localized: "settings.how", defaultValue: "How Evidence works"), systemImage: "list.bullet.clipboard")
                    }
                    Button {
                        confirmReplay = true
                    } label: {
                        Label(String(localized: "settings.replay", defaultValue: "Replay onboarding"), systemImage: "arrow.counterclockwise")
                    }
                }

                Section {
                    PrivacyNoticeView()
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(String(localized: "settings.nav", defaultValue: "Settings"))
            .accessibilityIdentifier("settings.root")
            .navigationDestination(for: AppRoute.self) { route in
                settingsDestination(route)
            }
            .confirmationDialog(
                String(localized: "settings.replay.confirm", defaultValue: "Replay onboarding?"),
                isPresented: $confirmReplay,
                titleVisibility: .visible
            ) {
                Button(String(localized: "settings.replay", defaultValue: "Replay onboarding")) {
                    Task { await replayOnboarding() }
                }
                Button(String(localized: "action.cancel", defaultValue: "Cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "settings.replay.message", defaultValue: "Your collection stays. Onboarding screens will appear again."))
            }
        }
    }

    @ViewBuilder
    private func settingsDestination(_ route: AppRoute) -> some View {
        switch route {
        case .syncSettings:
            SyncSettingsView()
        case .authentication:
            AuthenticationView()
        case .appLockSettings:
            AppLockSettingsView()
        case .privacy:
            PrivacyView()
        case .safetyInformation:
            SafetyInformationView()
        case .accessibilityStatement:
            AccessibilityStatementView()
        case .notificationSettings:
            NotificationSettingsView()
        case .meaningfulDateSettings:
            MeaningfulDateSettingsView()
        case .export:
            ExportView()
        case .deleteData:
            DeleteDataView()
        case .deleteAccount:
            DeleteAccountView()
        case .categoryManager:
            CategoryManagerView()
        case .about:
            AboutView()
        case .howEvidenceWorks:
            HowEvidenceWorksView()
        case .localToCloudMigration:
            LocalToCloudMigrationView()
        case .conflictResolution:
            ConflictResolutionView()
        case .magicLink:
            MagicLinkView()
        default:
            Text(String(localized: "error.unavailable", defaultValue: "This screen is unavailable."))
        }
    }

    private func replayOnboarding() async {
        let profile = await container.ensureProfile()
        profile.onboardingCompletedAt = nil
        profile.touch()
        try? await container.profileRepository.save(profile)
        UserDefaults.standard.set(OnboardingStep.productPromise.rawValue, forKey: "evidence.onboarding.step")
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.md) {
                Text(EvidenceTheme.brandName)
                    .font(.evidenceDisplay())
                    .accessibilityAddTraits(.isHeader)
                Text(EvidenceTheme.tagline)
                    .font(.evidenceTitle(22))
                Text(
                    String(
                        localized: "about.body",
                        defaultValue: "Evidence helps you preserve and retrieve meaningful reminders of who you are during difficult moments. It is not a social network, nostalgia gallery, or medical tool."
                    )
                )
                .font(.evidenceBody())

                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text(String(localized: "about.version", defaultValue: "Version \(version)"))
                        .font(.evidenceCaption())
                        .foregroundStyle(EvidenceFallbackColors.muted)
                }

                PrivacyNoticeView()
            }
            .padding(EvidenceTheme.Spacing.lg)
        }
        .navigationTitle(String(localized: "about.nav", defaultValue: "About"))
    }
}

struct HowEvidenceWorksView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.lg) {
                SectionHeader(
                    title: String(localized: "how.title", defaultValue: "How Evidence works")
                )
                step(1, String(localized: "how.1", defaultValue: "Save meaningful evidence — words, accomplishments, photos with meaning."))
                step(2, String(localized: "how.2", defaultValue: "Explain why future you may need it."))
                step(3, String(localized: "how.3", defaultValue: "When a feeling or need arises, retrieve one relevant reminder at a time."))
                Text(
                    String(
                        localized: "how.note",
                        defaultValue: "Evidence does not surface random memories. It uses the meaning and tags you choose."
                    )
                )
                .font(.evidenceBody())
                .foregroundStyle(EvidenceFallbackColors.muted)
                PrivacyNoticeView()
            }
            .padding(EvidenceTheme.Spacing.lg)
        }
        .navigationTitle(String(localized: "how.nav", defaultValue: "How it works"))
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: EvidenceTheme.Spacing.sm) {
            Text("\(number)")
                .font(.evidenceTitle(18))
                .foregroundStyle(EvidenceFallbackColors.accent)
                .frame(width: 28, alignment: .leading)
                .accessibilityHidden(true)
            Text(text)
                .font(.evidenceBody())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(number). \(text)")
    }
}
