import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.md) {
                SectionHeader(
                    title: String(localized: "privacy.title", defaultValue: "Privacy"),
                    subtitle: String(localized: "privacy.subtitle", defaultValue: "Accurate claims about what Evidence does.")
                )

                privacyPoint(String(localized: "privacy.1", defaultValue: "Entries are saved locally first on your device."))
                privacyPoint(String(localized: "privacy.2", defaultValue: "Cloud synchronization is optional and requires sign-in."))
                privacyPoint(String(localized: "privacy.3", defaultValue: "Cloud-synced data is stored in your private Supabase account with row-level security."))
                privacyPoint(String(localized: "privacy.4", defaultValue: "Media is stored in a private bucket, not a public gallery."))
                privacyPoint(String(localized: "privacy.5", defaultValue: "Evidence does not sell your data."))
                privacyPoint(String(localized: "privacy.6", defaultValue: "Evidence does not include advertising trackers or analytics SDKs."))
                privacyPoint(String(localized: "privacy.7", defaultValue: "Private entry content is not sent to an AI service."))
                privacyPoint(String(localized: "privacy.8", defaultValue: "Notification previews are generic by default."))
                privacyPoint(String(localized: "privacy.9", defaultValue: "App lock can hide your collection behind device authentication."))
                privacyPoint(String(localized: "privacy.10", defaultValue: "Signing out does not automatically delete local data."))

                PrivacyNoticeView()
            }
            .padding(EvidenceTheme.Spacing.lg)
        }
        .navigationTitle(String(localized: "privacy.nav", defaultValue: "Privacy"))
    }

    private func privacyPoint(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle")
            .font(.evidenceBody())
            .labelStyle(.titleAndIcon)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SafetyInformationView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.md) {
                SectionHeader(
                    title: String(localized: "safetyInfo.title", defaultValue: "Safety and support"),
                    subtitle: String(
                        localized: "safetyInfo.subtitle",
                        defaultValue: "Evidence is a wellness app for personal reflection. It is not a crisis counselor."
                    )
                )

                Text(
                    String(
                        localized: "safetyInfo.body",
                        defaultValue: "If you are in immediate danger or thinking about harming yourself or someone else, contact local emergency services or a trusted person now."
                    )
                )
                .font(.evidenceBody())

                Text(
                    String(
                        localized: "safetyInfo.local",
                        defaultValue: "When optional check-in notes include clear danger language, Evidence may pause ordinary recommendations and show supportive next steps. Classifications stay on-device and are not medical conclusions."
                    )
                )
                .font(.evidenceBody())
                .foregroundStyle(EvidenceFallbackColors.muted)

                PrivacyNoticeView()

                PrimaryButton(
                    title: String(localized: "safetyInfo.ack", defaultValue: "I understand")
                ) {
                    Task {
                        let profile = await container.ensureProfile()
                        profile.hasSeenSafetyInformation = true
                        profile.touch()
                        try? await container.profileRepository.save(profile)
                    }
                }
            }
            .padding(EvidenceTheme.Spacing.lg)
        }
        .navigationTitle(String(localized: "safetyInfo.nav", defaultValue: "Safety"))
    }
}

struct AccessibilityStatementView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.md) {
                SectionHeader(
                    title: String(localized: "a11y.title", defaultValue: "Accessibility"),
                    subtitle: String(
                        localized: "a11y.subtitle",
                        defaultValue: "Evidence aims for WCAG 2.2 Level AA principles with native iOS accessibility."
                    )
                )
                bullet(String(localized: "a11y.1", defaultValue: "VoiceOver labels, values, hints, and traits on interactive controls."))
                bullet(String(localized: "a11y.2", defaultValue: "Dynamic Type through accessibility sizes with layout reflow."))
                bullet(String(localized: "a11y.3", defaultValue: "Meaning is not conveyed by color alone."))
                bullet(String(localized: "a11y.4", defaultValue: "Practical minimum touch targets and visible selected states."))
                bullet(String(localized: "a11y.5", defaultValue: "Image descriptions can be stored separately from emotional meaning."))
                bullet(String(localized: "a11y.6", defaultValue: "Reduce Motion and Differentiate Without Color are respected where SwiftUI provides them."))
                bullet(String(localized: "a11y.7", defaultValue: "No auto-advancing screens without a user action."))
            }
            .padding(EvidenceTheme.Spacing.lg)
        }
        .navigationTitle(String(localized: "a11y.nav", defaultValue: "Accessibility"))
    }

    private func bullet(_ text: String) -> some View {
        Label(text, systemImage: "circle.fill")
            .font(.evidenceBody())
            .symbolRenderingMode(.hierarchical)
            .labelStyle(.titleAndIcon)
    }
}
