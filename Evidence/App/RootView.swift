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
                if container.appLock.isLocked && container.appLock.isLockEnabled {
                    lockScreen
                } else if !(profile?.hasCompletedOnboarding ?? false) {
                    OnboardingContainerView()
                } else {
                    MainTabView()
                }
            }

            if container.appLock.shouldShowPrivacyCover {
                AppLockCoverView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: container.appLock.isLocked)
        .animation(.easeInOut(duration: 0.15), value: container.appLock.shouldShowPrivacyCover)
    }

    private var lockScreen: some View {
        VStack(spacing: EvidenceTheme.Spacing.lg) {
            Spacer()
            Text(EvidenceTheme.brandName)
                .font(.evidenceDisplay())
                .accessibilityAddTraits(.isHeader)
            Text(String(localized: "lock.subtitle", defaultValue: "Your collection is locked."))
                .font(.evidenceBody())
                .foregroundStyle(EvidenceFallbackColors.muted)
                .multilineTextAlignment(.center)

            PrimaryButton(
                title: String(
                    localized: "lock.unlock",
                    defaultValue: "Unlock with \(container.appLock.biometricDisplayName)"
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
            PrivacyNoticeView()
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
        let success = await container.appLock.unlock()
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
