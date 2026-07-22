import SwiftUI
import SwiftData

/// Skippable, resumable onboarding for screens 1–8.
struct OnboardingContainerView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [AppProfile]

    @State private var viewModel = OnboardingViewModel()
    @State private var path = NavigationPath()

    private var profile: AppProfile? { profiles.first }

    var body: some View {
        NavigationStack(path: $path) {
            stepView(for: viewModel.currentStep)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if viewModel.currentStep != .appLock {
                            Button(String(localized: "onboarding.skip", defaultValue: "Skip for now")) {
                                Task { await finish(skipped: true) }
                            }
                            .accessibilityHint(String(localized: "onboarding.skip.hint", defaultValue: "Skips remaining onboarding steps"))
                        }
                    }
                }
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
        }
        .onAppear {
            viewModel.restoreProgress()
            if let profile {
                viewModel.selectedUseCases = Set(profile.selectedUseCases)
            }
        }
        .onChange(of: viewModel.currentStep) { _, newValue in
            viewModel.persistProgress(newValue)
        }
    }

    @ViewBuilder
    private func stepView(for step: OnboardingStep) -> some View {
        switch step {
        case .productPromise:
            ProductPromiseOnboardingView(onContinue: { viewModel.advance() })
        case .howItWorks:
            HowItWorksOnboardingView(onContinue: { viewModel.advance() }, onBack: { viewModel.back() })
        case .privacy:
            PrivacyOnboardingView(onContinue: { viewModel.advance() }, onBack: { viewModel.back() })
        case .useCaseSelection:
            UseCaseSelectionOnboardingView(
                selected: $viewModel.selectedUseCases,
                onContinue: {
                    Task { await saveUseCases(); viewModel.advance() }
                },
                onBack: { viewModel.back() }
            )
        case .firstEntry:
            FirstEntryOnboardingView(
                onWrite: { path.append(AppRoute.entryEditor(.firstEntry)) },
                onPhoto: { path.append(AppRoute.entryEditor(.firstEntry)) },
                onGuided: { path.append(AppRoute.grounding) },
                onSkip: { viewModel.advance() },
                onBack: { viewModel.back() }
            )
        case .notificationSetup:
            NotificationSetupOnboardingView(
                viewModel: viewModel,
                onContinue: { viewModel.advance() },
                onBack: { viewModel.back() }
            )
        case .cloudSync:
            CloudSyncOnboardingView(
                onSignIn: { path.append(AppRoute.authentication) },
                onContinue: { viewModel.advance() },
                onBack: { viewModel.back() }
            )
        case .appLock:
            AppLockOnboardingView(
                onEnable: {
                    Task { await enableAppLock(); await finish(skipped: false) }
                },
                onSkip: {
                    Task { await finish(skipped: false) }
                },
                onBack: { viewModel.back() }
            )
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .entryEditor(let presentation):
            EntryEditorView(presentation: presentation) {
                viewModel.advance()
            }
        case .grounding:
            RecommendationView(mode: .standaloneGrounding) {
                viewModel.advance()
            }
        case .authentication:
            AuthenticationView(onFinished: {
                path.removeLast()
                viewModel.advance()
            })
        default:
            Text(String(localized: "error.unavailable", defaultValue: "This screen is unavailable."))
        }
    }

    private func saveUseCases() async {
        let profile = await container.ensureProfile()
        profile.selectedUseCases = Array(viewModel.selectedUseCases)
        profile.touch()
        try? await container.profileRepository.save(profile)
    }

    private func enableAppLock() async {
        container.appLock.isLockEnabled = true
        let profile = await container.ensureProfile()
        profile.appLockEnabled = true
        profile.touch()
        try? await container.profileRepository.save(profile)
    }

    private func finish(skipped: Bool) async {
        let profile = await container.ensureProfile()
        if !viewModel.selectedUseCases.isEmpty {
            profile.selectedUseCases = Array(viewModel.selectedUseCases)
        }
        profile.markOnboardingCompleted(at: container.environment.dateProvider.now)
        try? await container.profileRepository.save(profile)
        viewModel.clearProgress()
        _ = skipped
    }
}

enum OnboardingStep: Int, CaseIterable, Codable {
    case productPromise
    case howItWorks
    case privacy
    case useCaseSelection
    case firstEntry
    case notificationSetup
    case cloudSync
    case appLock

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }
}

@Observable
@MainActor
final class OnboardingViewModel {
    var currentStep: OnboardingStep = .productPromise
    var selectedUseCases: Set<IntendedUseCase> = []
    var notificationsEnabledDesire = false
    var selectedWeekdays: [Int] = [2, 3, 4, 5, 6]
    var deliveryHour = 9
    var deliveryMinute = 0

    private let stepKey = "evidence.onboarding.step"

    func advance() {
        if let next = currentStep.next {
            currentStep = next
        }
    }

    func back() {
        if let previous = currentStep.previous {
            currentStep = previous
        }
    }

    func restoreProgress() {
        let raw = UserDefaults.standard.integer(forKey: stepKey)
        if let step = OnboardingStep(rawValue: raw) {
            currentStep = step
        }
    }

    func persistProgress(_ step: OnboardingStep) {
        UserDefaults.standard.set(step.rawValue, forKey: stepKey)
    }

    func clearProgress() {
        UserDefaults.standard.removeObject(forKey: stepKey)
    }
}
