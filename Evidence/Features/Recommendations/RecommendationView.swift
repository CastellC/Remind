import SwiftUI
import SwiftData

enum RecommendationMode {
    case fromCheckIn
    case standaloneGrounding
}

struct RecommendationView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    var mode: RecommendationMode = .fromCheckIn
    var onFinished: (() -> Void)? = nil

    @State private var viewModel = RecommendationViewModel()
    @State private var showBreakOffer = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.md) {
                if let result = viewModel.current {
                    recommendationContent(result)
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .accessibilityLabel(String(localized: "recommendation.loading", defaultValue: "Finding something relevant"))
                } else {
                    EmptyStateView(
                        title: String(localized: "recommendation.empty.title", defaultValue: "Nothing to show right now"),
                        message: String(
                            localized: "recommendation.empty.message",
                            defaultValue: "Try adding evidence, or take a quiet break."
                        ),
                        systemImage: "leaf",
                        actionTitle: String(localized: "recommendation.finish", defaultValue: "Finish"),
                        action: { finish() }
                    )
                }

                if showBreakOffer {
                    breakOffer
                }

                PrivacyNoticeView()
            }
            .padding(EvidenceTheme.Spacing.lg)
        }
        .navigationTitle(String(localized: "recommendation.nav", defaultValue: "Reminder"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(container: container, mode: mode)
        }
    }

    @ViewBuilder
    private func recommendationContent(_ result: RecommendationResult) -> some View {
        if result.isGuided {
            Text(String(localized: "recommendation.guidedLabel", defaultValue: "Guided reminder"))
                .font(.evidenceCaption().weight(.semibold))
                .foregroundStyle(EvidenceFallbackColors.accent)
        }

        Text(result.item.title)
            .font(.evidenceTitle(24))
            .accessibilityAddTraits(.isHeader)

        switch result.item {
        case .personal(let entry):
            if let body = entry.bodyText, !body.isEmpty {
                Text(body)
                    .font(.evidenceBody())
            }
            Text(entry.meaningPromptAnswer)
                .font(.evidenceBody().weight(.medium))
                .foregroundStyle(EvidenceFallbackColors.ink)
                .padding(.top, EvidenceTheme.Spacing.xs)
        case .guided(let guided):
            Text(guided.body)
                .font(.evidenceBody())
        }

        Text(result.selectionReason)
            .font(.evidenceCaption())
            .foregroundStyle(EvidenceFallbackColors.muted)
            .padding(.top, EvidenceTheme.Spacing.xs)
            .accessibilityLabel(
                String(
                    localized: "recommendation.reason",
                    defaultValue: "Why this was shown: \(result.selectionReason)"
                )
            )

        FeedbackBar { response in
            Task { await handleFeedback(response) }
        }

        SecondaryButton(
            title: String(localized: "recommendation.showAnother", defaultValue: "Show another")
        ) {
            Task { await showAnother() }
        }

        PrimaryButton(
            title: String(localized: "recommendation.finish", defaultValue: "Finish"),
            action: finish
        )
    }

    private var breakOffer: some View {
        VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.sm) {
            Text(String(localized: "recommendation.break.title", defaultValue: "Would a pause help?"))
                .font(.evidenceTitle(18))
            SecondaryButton(
                title: String(localized: "recommendation.break.grounding", defaultValue: "Try a grounding exercise")
            ) {
                Task {
                    container.preferNeutralGrounding = true
                    await viewModel.load(container: container, mode: .standaloneGrounding)
                    showBreakOffer = false
                }
            }
            SecondaryButton(
                title: String(localized: "recommendation.break.pause", defaultValue: "Take a break")
            ) {
                finish()
            }
            SecondaryButton(
                title: String(localized: "recommendation.break.end", defaultValue: "End check-in")
            ) {
                finish()
            }
        }
        .padding(EvidenceTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: EvidenceTheme.Radius.medium, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func handleFeedback(_ response: FeedbackResponse) async {
        await viewModel.recordFeedback(response, container: container)
        if response.shouldStopEmotionallyChargedContent {
            container.preferNeutralGrounding = true
            await viewModel.load(container: container, mode: .standaloneGrounding)
        }
    }

    private func showAnother() async {
        container.showAnotherCount += 1
        if container.showAnotherCount >= 3 {
            showBreakOffer = true
        }
        await viewModel.loadNext(container: container, mode: mode)
    }

    private func finish() {
        container.resetCheckInSession()
        onFinished?()
        dismiss()
    }
}

@Observable
@MainActor
final class RecommendationViewModel {
    var current: RecommendationResult?
    var isLoading = false
    private var checkIn: CheckIn?

    func load(container: AppContainer, mode: RecommendationMode) async {
        isLoading = true
        defer { isLoading = false }

        if mode == .standaloneGrounding {
            container.preferNeutralGrounding = true
        }

        if let id = container.activeCheckInID {
            checkIn = try? await container.checkInRepository.fetch(id: id)
        }

        current = await select(container: container, mode: mode)
        if let current {
            rememberShown(current, container: container)
        }
    }

    func loadNext(container: AppContainer, mode: RecommendationMode) async {
        isLoading = true
        defer { isLoading = false }
        current = await select(container: container, mode: mode)
        if let current {
            rememberShown(current, container: container)
        }
    }

    func recordFeedback(_ response: FeedbackResponse, container: AppContainer) async {
        guard let current else { return }
        var entryID: UUID?
        var guidedID: UUID?
        switch current.item {
        case .personal(let entry):
            entryID = entry.id
        case .guided(let guided):
            guidedID = guided.id
        }

        let feedback = RecommendationFeedback(
            ownerUserID: container.authentication.currentUserID,
            recommendationSessionID: nil,
            checkInID: checkIn?.id,
            evidenceEntryID: entryID,
            guidedContentID: guidedID,
            response: response,
            emotionAtTime: checkIn?.emotion,
            supportNeedAtTime: checkIn?.supportNeed,
            syncStatus: .localOnly
        )
        try? await container.feedbackRepository.save(feedback)

        if response == .doNotUseForThisFeeling || response == .madeThingsHarder {
            // Soft exclusion for the rest of the session is handled via recentlyShown + preferNeutralGrounding.
        }
    }

    private func select(container: AppContainer, mode: RecommendationMode) async -> RecommendationResult? {
        let entries = ((try? await container.entryRepository.fetchAll(includeArchived: false)) ?? [])
            .map(RecommendableEntry.init(entry:))
        let feedback = ((try? await container.feedbackRepository.fetchRecent(limit: 100)) ?? []).map {
            FeedbackSnapshot(
                evidenceEntryID: $0.evidenceEntryID,
                guidedContentID: $0.guidedContentID,
                response: $0.response,
                emotionAtTime: $0.emotionAtTime,
                supportNeedAtTime: $0.supportNeedAtTime,
                createdAt: $0.createdAt
            )
        }

        let emotion = checkIn?.emotion ?? .uncertain
        let need = checkIn?.supportNeed ?? (mode == .standaloneGrounding ? .grounding : .quietReflection)

        var excludeEntries = Set(container.recentlyShownInSession.compactMap(\.entryID))
        var excludeGuided = Set(container.recentlyShownInSession.compactMap(\.guidedContentID))

        let input = RecommendationInput(
            emotion: emotion,
            supportNeed: need,
            intensity: checkIn?.intensity,
            entries: entries,
            guidedContent: container.guidedContent,
            feedback: feedback,
            recentlyShown: container.recentlyShownInSession,
            excludeEntryIDs: excludeEntries,
            excludeGuidedIDs: excludeGuided,
            preferNeutralGrounding: container.preferNeutralGrounding || mode == .standaloneGrounding
        )

        return container.recommendationEngine.recommendCopyingRNG(from: input)
    }

    private func rememberShown(_ result: RecommendationResult, container: AppContainer) {
        switch result.item {
        case .personal(let entry):
            container.recentlyShownInSession.append(
                RecentlyShownItem(entryID: entry.id, guidedContentID: nil, shownAt: Date())
            )
        case .guided(let guided):
            container.recentlyShownInSession.append(
                RecentlyShownItem(entryID: nil, guidedContentID: guided.id, shownAt: Date())
            )
        }
    }
}
