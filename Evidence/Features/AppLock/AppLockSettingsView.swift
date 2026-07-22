import SwiftUI
import SwiftData

struct AppLockSettingsView: View {
    @Environment(AppContainer.self) private var container
    @Query private var profiles: [AppProfile]

    @State private var isEnabled = false
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                Toggle(
                    String(
                        localized: "appLock.enable",
                        defaultValue: "Require \(container.appLock.biometricDisplayName)"
                    ),
                    isOn: $isEnabled
                )
                .onChange(of: isEnabled) { _, newValue in
                    Task { await setEnabled(newValue) }
                }
            } footer: {
                Text(
                    String(
                        localized: "appLock.footer",
                        defaultValue: "Uses Face ID, Touch ID, or your device passcode. Evidence does not create a separate password."
                    )
                )
            }

            if !container.appLock.canUseBiometrics() {
                Section {
                    Text(
                        String(
                            localized: "appLock.unavailable",
                            defaultValue: "Device authentication is unavailable. App lock cannot be enabled right now."
                        )
                    )
                    .font(.evidenceCaption())
                    .foregroundStyle(EvidenceFallbackColors.muted)
                }
            }

            if let message {
                Section {
                    Text(message)
                        .font(.evidenceCaption())
                        .foregroundStyle(EvidenceFallbackColors.muted)
                }
            }
        }
        .navigationTitle(String(localized: "appLock.nav", defaultValue: "App lock"))
        .onAppear {
            isEnabled = container.appLock.isLockEnabled
        }
    }

    private func setEnabled(_ enabled: Bool) async {
        if enabled && !container.appLock.canUseBiometrics() {
            isEnabled = false
            message = String(
                localized: "appLock.cannotEnable",
                defaultValue: "Could not enable app lock because device authentication is unavailable."
            )
            return
        }
        if enabled {
            let unlocked = await container.appLock.unlock()
            guard unlocked else {
                isEnabled = false
                message = String(
                    localized: "appLock.cancelled",
                    defaultValue: "App lock was not enabled."
                )
                return
            }
        }
        container.appLock.isLockEnabled = enabled
        let profile = await container.ensureProfile()
        profile.appLockEnabled = enabled
        profile.touch()
        try? await container.profileRepository.save(profile)
        message = enabled
            ? String(localized: "appLock.enabled", defaultValue: "App lock is on.")
            : String(localized: "appLock.disabled", defaultValue: "App lock is off.")
    }
}

/// Opaque privacy cover for the app switcher / inactive state.
struct AppLockCoverView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    EvidenceFallbackColors.canvasLight,
                    EvidenceFallbackColors.softFill,
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: EvidenceTheme.Spacing.md) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(EvidenceFallbackColors.accent)
                    .accessibilityHidden(true)
                Text(EvidenceTheme.brandName)
                    .font(.evidenceDisplay(32))
                Text(String(localized: "appLock.cover", defaultValue: "Your collection is private."))
                    .font(.evidenceBody())
                    .foregroundStyle(EvidenceFallbackColors.muted)
            }
            .accessibilityElement(children: .combine)
        }
        .accessibilityLabel(String(localized: "appLock.cover.a11y", defaultValue: "Evidence is locked. Content is hidden."))
    }
}
