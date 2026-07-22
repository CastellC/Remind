import SwiftUI

struct ProductPromiseOnboardingView: View {
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: String(localized: "onboarding.promise.title", defaultValue: "Remember what is true."),
            bodyText: String(
                localized: "onboarding.promise.body",
                defaultValue: "Keep meaningful words, accomplishments, and reminders close for the moments when they are hardest to remember."
            ),
            brandFirst: true,
            onContinue: onContinue
        )
    }
}

struct HowItWorksOnboardingView: View {
    let onContinue: () -> Void
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.lg) {
                SectionHeader(
                    title: String(localized: "onboarding.how.title", defaultValue: "How Evidence works"),
                    subtitle: String(
                        localized: "onboarding.how.subtitle",
                        defaultValue: "Three calm steps when you need them."
                    )
                )

                numberedRow(1, String(localized: "onboarding.how.1", defaultValue: "Save meaningful evidence."))
                numberedRow(2, String(localized: "onboarding.how.2", defaultValue: "Explain why future you may need it."))
                numberedRow(3, String(localized: "onboarding.how.3", defaultValue: "Retrieve it when a particular feeling or need arises."))

                Text(
                    String(
                        localized: "onboarding.how.note",
                        defaultValue: "Evidence does not surface random memories. It uses the meaning and tags you choose."
                    )
                )
                .font(.evidenceBody())
                .foregroundStyle(EvidenceFallbackColors.muted)

                PrimaryButton(
                    title: String(localized: "action.continue", defaultValue: "Continue"),
                    action: onContinue
                )
                SecondaryButton(
                    title: String(localized: "action.back", defaultValue: "Back"),
                    action: onBack
                )
            }
            .padding(EvidenceTheme.Spacing.lg)
        }
        .background(onboardingBackground)
    }

    private func numberedRow(_ number: Int, _ text: String) -> some View {
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

    private var onboardingBackground: some View {
        LinearGradient(
            colors: [EvidenceFallbackColors.canvasLight.opacity(0.9), Color(.systemBackground)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

struct PrivacyOnboardingView: View {
    let onContinue: () -> Void
    let onBack: () -> Void

    private let points: [String] = [
        String(localized: "onboarding.privacy.1", defaultValue: "Entries are saved locally first."),
        String(localized: "onboarding.privacy.2", defaultValue: "Cloud synchronization is optional."),
        String(localized: "onboarding.privacy.3", defaultValue: "Cloud-synced data stays in your private account."),
        String(localized: "onboarding.privacy.4", defaultValue: "Media is stored in a private bucket when sync is on."),
        String(localized: "onboarding.privacy.5", defaultValue: "Evidence does not sell your data."),
        String(localized: "onboarding.privacy.6", defaultValue: "Evidence does not use advertising trackers."),
        String(localized: "onboarding.privacy.7", defaultValue: "Private content is not sent to an AI service."),
        String(localized: "onboarding.privacy.8", defaultValue: "Notification previews are generic by default."),
        String(localized: "onboarding.privacy.9", defaultValue: "App lock can be enabled.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.md) {
                SectionHeader(
                    title: String(localized: "onboarding.privacy.title", defaultValue: "Privacy, plainly"),
                    subtitle: String(
                        localized: "onboarding.privacy.subtitle",
                        defaultValue: "Only claims that match what the app actually does."
                    )
                )
                ForEach(points, id: \.self) { point in
                    Label(point, systemImage: "checkmark.circle")
                        .font(.evidenceBody())
                        .foregroundStyle(EvidenceFallbackColors.ink)
                        .labelStyle(.titleAndIcon)
                }
                PrivacyNoticeView()
                PrimaryButton(
                    title: String(localized: "action.continue", defaultValue: "Continue"),
                    action: onContinue
                )
                SecondaryButton(
                    title: String(localized: "action.back", defaultValue: "Back"),
                    action: onBack
                )
            }
            .padding(EvidenceTheme.Spacing.lg)
        }
    }
}

struct UseCaseSelectionOnboardingView: View {
    @Binding var selected: Set<IntendedUseCase>
    let onContinue: () -> Void
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.md) {
                SectionHeader(
                    title: String(localized: "onboarding.use.title", defaultValue: "How do you hope to use Evidence?"),
                    subtitle: String(
                        localized: "onboarding.use.subtitle",
                        defaultValue: "Choose up to three. You can change this later."
                    )
                )
                ForEach(IntendedUseCase.allCases) { useCase in
                    let isOn = selected.contains(useCase)
                    SupportNeedStyleRow(
                        title: useCase.displayName,
                        isSelected: isOn
                    ) {
                        toggle(useCase)
                    }
                }
                PrimaryButton(
                    title: String(localized: "action.continue", defaultValue: "Continue"),
                    isEnabled: !selected.isEmpty,
                    action: onContinue
                )
                SecondaryButton(
                    title: String(localized: "action.back", defaultValue: "Back"),
                    action: onBack
                )
            }
            .padding(EvidenceTheme.Spacing.lg)
        }
    }

    private func toggle(_ useCase: IntendedUseCase) {
        if selected.contains(useCase) {
            selected.remove(useCase)
        } else if selected.count < IntendedUseCase.maxSelections {
            selected.insert(useCase)
        }
    }
}

struct SupportNeedStyleRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.evidenceBody())
                    .foregroundStyle(isSelected ? Color.white : EvidenceFallbackColors.ink)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.white : EvidenceFallbackColors.muted)
                    .accessibilityHidden(true)
            }
            .padding(EvidenceTheme.Spacing.md)
            .frame(minHeight: EvidenceTheme.minTouchTarget)
            .background(
                RoundedRectangle(cornerRadius: EvidenceTheme.Radius.medium, style: .continuous)
                    .fill(isSelected ? EvidenceFallbackColors.accent : Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityLabel(title)
    }
}

struct FirstEntryOnboardingView: View {
    let onWrite: () -> Void
    let onPhoto: () -> Void
    let onGuided: () -> Void
    let onSkip: () -> Void
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.md) {
                SectionHeader(
                    title: String(
                        localized: "onboarding.first.title",
                        defaultValue: "What is one thing you may need to remember on a difficult day?"
                    )
                )
                PrimaryButton(
                    title: String(localized: "onboarding.first.write", defaultValue: "Write a reminder"),
                    action: onWrite
                )
                SecondaryButton(
                    title: String(localized: "onboarding.first.photo", defaultValue: "Add a photo"),
                    action: onPhoto
                )
                SecondaryButton(
                    title: String(localized: "onboarding.first.guided", defaultValue: "Choose a guided reminder"),
                    action: onGuided
                )
                SecondaryButton(
                    title: String(localized: "action.skip", defaultValue: "Skip"),
                    action: onSkip
                )
                SecondaryButton(
                    title: String(localized: "action.back", defaultValue: "Back"),
                    action: onBack
                )
            }
            .padding(EvidenceTheme.Spacing.lg)
        }
    }
}

struct NotificationSetupOnboardingView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(AppContainer.self) private var container
    let onContinue: () -> Void
    let onBack: () -> Void
    @State private var isRequesting = false
    @State private var statusMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.md) {
                SectionHeader(
                    title: String(localized: "onboarding.notifications.title", defaultValue: "Optional reminders"),
                    subtitle: String(
                        localized: "onboarding.notifications.body",
                        defaultValue: "Evidence can gently remind you that your collection is here. Choose a schedule before the system asks for permission."
                    )
                )

                Toggle(
                    String(localized: "onboarding.notifications.enable", defaultValue: "I’d like reminders"),
                    isOn: $viewModel.notificationsEnabledDesire
                )
                .tint(EvidenceFallbackColors.accent)

                if viewModel.notificationsEnabledDesire {
                    DatePicker(
                        String(localized: "onboarding.notifications.time", defaultValue: "Reminder time"),
                        selection: Binding(
                            get: {
                                Calendar.current.date(
                                    from: DateComponents(hour: viewModel.deliveryHour, minute: viewModel.deliveryMinute)
                                ) ?? Date()
                            },
                            set: { date in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                                viewModel.deliveryHour = comps.hour ?? 9
                                viewModel.deliveryMinute = comps.minute ?? 0
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.evidenceCaption())
                        .foregroundStyle(EvidenceFallbackColors.muted)
                }

                PrimaryButton(
                    title: String(localized: "action.continue", defaultValue: "Continue"),
                    isLoading: isRequesting
                ) {
                    Task { await continueTapped() }
                }
                SecondaryButton(
                    title: String(localized: "action.back", defaultValue: "Back"),
                    action: onBack
                )
            }
            .padding(EvidenceTheme.Spacing.lg)
        }
    }

    private func continueTapped() async {
        guard viewModel.notificationsEnabledDesire else {
            onContinue()
            return
        }
        isRequesting = true
        defer { isRequesting = false }
        do {
            let granted = try await container.notifications.requestAuthorization()
            if granted {
                let schedule = ReminderSchedule(
                    isEnabled: true,
                    selectedWeekdays: viewModel.selectedWeekdays,
                    deliveryHour: viewModel.deliveryHour,
                    deliveryMinute: viewModel.deliveryMinute,
                    frequency: .weekdays,
                    genericPreviewOnly: true
                )
                try await container.reminderRepository.save(schedule)
                let entries = try await container.entryRepository.fetchAll(includeArchived: false)
                let profile = await container.ensureProfile()
                try await container.notifications.reschedule(
                    from: schedule,
                    entries: entries,
                    previewMode: profile.notificationPreviewMode
                )
                statusMessage = String(localized: "onboarding.notifications.granted", defaultValue: "Reminders are set.")
            } else {
                statusMessage = String(
                    localized: "onboarding.notifications.denied",
                    defaultValue: "Reminders stay off. You can enable them later in Settings."
                )
            }
            onContinue()
        } catch {
            statusMessage = String(
                localized: "onboarding.notifications.error",
                defaultValue: "Could not update reminders. You can try again in Settings."
            )
            onContinue()
        }
    }
}

struct CloudSyncOnboardingView: View {
    let onSignIn: () -> Void
    let onContinue: () -> Void
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.md) {
                SectionHeader(
                    title: String(localized: "onboarding.sync.title", defaultValue: "Optional cloud sync"),
                    subtitle: String(
                        localized: "onboarding.sync.body",
                        defaultValue: "Evidence works without an account. Signing in enables private synchronization across your devices."
                    )
                )
                Label(
                    String(localized: "onboarding.sync.apple", defaultValue: "Sign in with Apple is recommended."),
                    systemImage: "apple.logo"
                )
                Label(
                    String(localized: "onboarding.sync.magic", defaultValue: "Email magic link is available as a fallback."),
                    systemImage: "envelope"
                )
                PrimaryButton(
                    title: String(localized: "onboarding.sync.signIn", defaultValue: "Sign in"),
                    action: onSignIn
                )
                SecondaryButton(
                    title: String(localized: "onboarding.sync.later", defaultValue: "Continue without sync"),
                    action: onContinue
                )
                SecondaryButton(
                    title: String(localized: "action.back", defaultValue: "Back"),
                    action: onBack
                )
            }
            .padding(EvidenceTheme.Spacing.lg)
        }
    }
}

struct AppLockOnboardingView: View {
    @Environment(AppContainer.self) private var container
    let onEnable: () -> Void
    let onSkip: () -> Void
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.md) {
                SectionHeader(
                    title: String(localized: "onboarding.lock.title", defaultValue: "Optional app lock"),
                    subtitle: String(
                        localized: "onboarding.lock.body",
                        defaultValue: "Protect your collection with \(container.appLock.biometricDisplayName) or your device passcode."
                    )
                )
                if container.appLock.canUseBiometrics() {
                    PrimaryButton(
                        title: String(
                            localized: "onboarding.lock.enable",
                            defaultValue: "Enable \(container.appLock.biometricDisplayName)"
                        ),
                        action: onEnable
                    )
                } else {
                    Text(
                        String(
                            localized: "onboarding.lock.unavailable",
                            defaultValue: "Device authentication is unavailable on this device right now."
                        )
                    )
                    .font(.evidenceCaption())
                    .foregroundStyle(EvidenceFallbackColors.muted)
                }
                SecondaryButton(
                    title: String(localized: "onboarding.lock.skip", defaultValue: "Not now"),
                    action: onSkip
                )
                SecondaryButton(
                    title: String(localized: "action.back", defaultValue: "Back"),
                    action: onBack
                )
            }
            .padding(EvidenceTheme.Spacing.lg)
        }
    }
}

struct OnboardingScaffold: View {
    let title: String
    let bodyText: String
    var brandFirst: Bool = false
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.lg) {
            Spacer(minLength: EvidenceTheme.Spacing.xl)
            if brandFirst {
                Text(EvidenceTheme.brandName)
                    .font(.evidenceDisplay(40))
                    .foregroundStyle(EvidenceFallbackColors.accent)
                    .accessibilityAddTraits(.isHeader)
            }
            Text(title)
                .font(.evidenceDisplay(brandFirst ? 28 : 34))
                .foregroundStyle(EvidenceFallbackColors.ink)
                .accessibilityAddTraits(brandFirst ? [] : .isHeader)
            Text(bodyText)
                .font(.evidenceBody())
                .foregroundStyle(EvidenceFallbackColors.muted)
            Spacer()
            PrimaryButton(
                title: String(localized: "action.continue", defaultValue: "Continue"),
                action: onContinue
            )
        }
        .padding(EvidenceTheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [EvidenceFallbackColors.canvasLight, Color(.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}
