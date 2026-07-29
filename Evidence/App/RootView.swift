import SwiftUI
import SwiftData

/// Top-level router: lock → onboarding → main tabs.
struct RootView: View {
    @Environment(AppContainer.self) private var container
    @Query private var profiles: [AppProfile]

    @State private var isUnlocking = false
    @State private var unlockFailed = false

    private var profile: AppProfile? { profiles.first }

    var body: some View {
        ZStack {
            Group {
                if container.isAppLocked && container.appLock.isLockEnabled {
                    lockScreen
                } else if !(profile?.hasCompletedOnboarding ?? false) {
                    OnboardingContainerView()
                } else {
                    MainTabView()
                }
            }

            if container.shouldShowPrivacyCover {
                AppLockCoverView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: container.isAppLocked)
        .animation(.easeInOut(duration: 0.15), value: container.shouldShowPrivacyCover)
    }

    private var lockScreen: some View {
        VStack(spacing: EvidenceTheme.Spacing.lg) {
            Spacer()
            Text(EvidenceTheme.brandName)
                .font(.evidenceDisplay())
                .foregroundStyle(Color.evidenceAccent)
                .accessibilityAddTraits(.isHeader)
            Text(EvidenceTheme.tagline)
                .font(.evidenceBody())
                .foregroundStyle(EvidenceFallbackColors.muted)
                .multilineTextAlignment(.center)

            PrimaryButton(
                title: String(
                    localized: "lock.unlock",
                    defaultValue: "Unlock"
                ),
                isLoading: isUnlocking
            ) {
                Task { await unlock() }
            }
            .padding(.horizontal, EvidenceTheme.Spacing.lg)

            if unlockFailed {
                Text(String(localized: "lock.failed", defaultValue: "Could not unlock. Try again when you are ready."))
                    .font(.evidenceCaption())
                    .foregroundStyle(EvidenceFallbackColors.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, EvidenceTheme.Spacing.lg)
            }

            Spacer()
            Text(
                String(
                    localized: "lock.footer",
                    defaultValue: "Your collection stays private on this device."
                )
            )
            .font(.evidenceCaption())
            .foregroundStyle(EvidenceFallbackColors.muted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, EvidenceTheme.Spacing.lg)
            .padding(.bottom, EvidenceTheme.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [EvidenceFallbackColors.canvasLight, Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private func unlock() async {
        isUnlocking = true
        unlockFailed = false
        let success = await container.unlockApp()
        unlockFailed = !success
        isUnlocking = false
    }
}

#Preview {
    let container = AppContainer.preview()
    return RootView()
        .environment(container)
        .environmentObject(container.environment)
        .modelContainer(container.modelContainer)
}
