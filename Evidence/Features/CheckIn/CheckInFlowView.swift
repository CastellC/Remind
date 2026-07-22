import SwiftUI
import SwiftData

struct CheckInFlowView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = CheckInFlowViewModel()
    @State private var destination: AppRoute?

    var body: some View {
        Group {
            switch viewModel.step {
            case .emotion:
                EmotionStepView(selected: $viewModel.emotion) {
                    viewModel.step = .supportNeed
                }
            case .supportNeed:
                SupportNeedStepView(selected: $viewModel.supportNeed) {
                    viewModel.step = .intensity
                } onBack: {
                    viewModel.step = .emotion
                }
            case .intensity:
                IntensityStepView(
                    intensity: $viewModel.intensity,
                    note: $viewModel.optionalNote,
                    keepNoteLocalOnly: $viewModel.keepNoteLocalOnly
                ) {
                    Task { await completeAndContinue() }
                } onSkip: {
                    viewModel.intensity = nil
                    Task { await completeAndContinue() }
                } onBack: {
                    viewModel.step = .supportNeed
                }
            }
        }
        .navigationTitle(String(localized: "checkIn.nav", defaultValue: "Check in"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $destination) { route in
            switch route {
            case .recommendation:
                RecommendationView(mode: .fromCheckIn)
            case .safetySupport(let state):
                SafetyFlowView(state: state) {
                    destination = .recommendation
                }
            case .grounding:
                RecommendationView(mode: .standaloneGrounding)
            default:
                EmptyView()
            }
        }
    }

    private func completeAndContinue() async {
        guard let emotion = viewModel.emotion, let need = viewModel.supportNeed else { return }

        var safety = SafetyState.standard
        if let note = viewModel.optionalNote, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            safety = container.safetyDetector.evaluate(note)
        }

        let profile = await container.ensureProfile()
        let checkIn = CheckIn(
            ownerUserID: profile.authenticatedUserID,
            emotion: emotion,
            intensity: viewModel.intensity,
            supportNeed: need,
            optionalNote: viewModel.optionalNote,
            keepNoteLocalOnly: viewModel.keepNoteLocalOnly || profile.keepCheckInNotesLocalOnly,
            safetyState: safety,
            syncStatus: profile.cloudSyncEnabled ? .pendingUpload : .localOnly
        )
        checkIn.complete(at: container.environment.dateProvider.now)
        try? await container.checkInRepository.save(checkIn)
        container.activeCheckInID = checkIn.id
        container.preferNeutralGrounding = false
        container.showAnotherCount = 0
        container.recentlyShownInSession = []

        if safety.isElevatedOrImmediate {
            destination = .safetySupport(safety)
        } else {
            destination = .recommendation
        }
    }
}

enum CheckInStep {
    case emotion
    case supportNeed
    case intensity
}

@Observable
@MainActor
final class CheckInFlowViewModel {
    var step: CheckInStep = .emotion
    var emotion: Emotion?
    var supportNeed: SupportNeed?
    var intensity: Int?
    var optionalNote: String = ""
    var keepNoteLocalOnly: Bool = true
}

struct EmotionStepView: View {
    @Binding var selected: Emotion?
    let onContinue: () -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.md) {
                SectionHeader(
                    title: String(localized: "checkIn.emotion.title", defaultValue: "What feels closest right now?")
                )
                LazyVGrid(columns: columns, spacing: EvidenceTheme.Spacing.sm) {
                    ForEach(Emotion.allCases) { emotion in
                        EmotionChoiceCard(
                            emotion: emotion,
                            isSelected: selected == emotion
                        ) {
                            selected = emotion
                        }
                    }
                }
                PrimaryButton(
                    title: String(localized: "action.continue", defaultValue: "Continue"),
                    isEnabled: selected != nil,
                    action: onContinue
                )
            }
            .padding(EvidenceTheme.Spacing.lg)
        }
    }
}

struct SupportNeedStepView: View {
    @Binding var selected: SupportNeed?
    let onContinue: () -> Void
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.md) {
                SectionHeader(
                    title: String(localized: "checkIn.need.title", defaultValue: "What kind of support would help?")
                )
                ForEach(SupportNeed.allCases) { need in
                    SupportNeedChoiceCard(
                        supportNeed: need,
                        isSelected: selected == need
                    ) {
                        selected = need
                    }
                }
                PrimaryButton(
                    title: String(localized: "action.continue", defaultValue: "Continue"),
                    isEnabled: selected != nil,
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

struct IntensityStepView: View {
    @Binding var intensity: Int?
    @Binding var note: String
    @Binding var keepNoteLocalOnly: Bool
    let onContinue: () -> Void
    let onSkip: () -> Void
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.md) {
                SectionHeader(
                    title: String(localized: "checkIn.intensity.title", defaultValue: "How intense does this feel?"),
                    subtitle: String(localized: "checkIn.intensity.optional", defaultValue: "Optional")
                )
                ForEach(1...5, id: \.self) { value in
                    let label = CheckIn.intensityLabels[value] ?? "\(value)"
                    SupportNeedStyleRow(
                        title: "\(value). \(label)",
                        isSelected: intensity == value
                    ) {
                        intensity = value
                    }
                }

                Text(String(localized: "checkIn.note.label", defaultValue: "Optional note"))
                    .font(.evidenceCaption().weight(.medium))
                TextField(
                    String(localized: "checkIn.note.placeholder", defaultValue: "Anything you want to add"),
                    text: $note,
                    axis: .vertical
                )
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)

                Toggle(
                    String(localized: "checkIn.note.local", defaultValue: "Keep this note on this device only"),
                    isOn: $keepNoteLocalOnly
                )
                .tint(EvidenceFallbackColors.accent)

                PrimaryButton(
                    title: String(localized: "action.continue", defaultValue: "Continue"),
                    action: onContinue
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
