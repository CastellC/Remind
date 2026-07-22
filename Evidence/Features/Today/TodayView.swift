import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(AppContainer.self) private var container
    @Query(filter: #Predicate<EvidenceEntry> { !$0.isArchived }, sort: \EvidenceEntry.updatedAt, order: .reverse)
    private var entries: [EvidenceEntry]

    @State private var viewModel = TodayViewModel()
    @State private var path = NavigationPath()

    private var visibleEntries: [EvidenceEntry] {
        entries.filter { $0.deletedAt == nil && !$0.pendingDeletion }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.lg) {
                    brandHeader

                    if visibleEntries.isEmpty {
                        EmptyStateView(
                            title: String(localized: "today.empty.title", defaultValue: "Your collection is ready"),
                            message: String(
                                localized: "today.empty.message",
                                defaultValue: "Add your first reminder of what is true."
                            ),
                            systemImage: "sparkles",
                            actionTitle: String(localized: "today.empty.add", defaultValue: "Add your first reminder"),
                            action: { path.append(AppRoute.entryEditor(.create)) }
                        )
                        SecondaryButton(
                            title: String(localized: "today.empty.guided", defaultValue: "View a guided reminder")
                        ) {
                            path.append(AppRoute.grounding)
                        }
                        SecondaryButton(
                            title: String(localized: "today.empty.grounding", defaultValue: "Try a grounding exercise")
                        ) {
                            path.append(AppRoute.grounding)
                        }
                    } else {
                        SectionHeader(
                            title: String(localized: "today.heading", defaultValue: "Today"),
                            subtitle: String(
                                localized: "today.subheading",
                                defaultValue: "Check in when you want support. There is no pressure to start."
                            )
                        )

                        PrimaryButton(
                            title: String(localized: "today.checkIn", defaultValue: "Check in")
                        ) {
                            container.resetCheckInSession()
                            path.append(AppRoute.checkIn)
                        }
                        .accessibilityIdentifier("today.checkIn")

                        SecondaryButton(
                            title: String(localized: "today.openCollection", defaultValue: "Open my collection")
                        ) {
                            viewModel.showCollectionHint = true
                        }

                        SecondaryButton(
                            title: String(localized: "today.addEvidence", defaultValue: "Add evidence")
                        ) {
                            path.append(AppRoute.entryEditor(.create))
                        }
                        .accessibilityIdentifier("today.addEvidence")

                        SecondaryButton(
                            title: String(localized: "today.grounding", defaultValue: "Try a grounding exercise")
                        ) {
                            path.append(AppRoute.grounding)
                        }

                        if let suggestion = viewModel.gentleSuggestion(from: visibleEntries) {
                            VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.xs) {
                                Text(String(localized: "today.suggestion", defaultValue: "From your collection"))
                                    .font(.evidenceCaption().weight(.medium))
                                    .foregroundStyle(EvidenceFallbackColors.muted)
                                Button {
                                    path.append(AppRoute.entryDetail(suggestion.id))
                                } label: {
                                    EvidenceCard(
                                        title: suggestion.title,
                                        meaningSnippet: suggestion.meaningPromptAnswer,
                                        entryType: suggestion.entryType,
                                        isFavorite: suggestion.isFavorite,
                                        showsFavoriteControl: false
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    PrivacyNoticeView()
                }
                .padding(EvidenceTheme.Spacing.lg)
            }
            .background(
                LinearGradient(
                    colors: [EvidenceFallbackColors.canvasLight.opacity(0.85), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle(EvidenceTheme.brandName)
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: AppRoute.self) { route in
                todayDestination(route)
            }
            .alert(
                String(localized: "today.collectionHint.title", defaultValue: "Your collection"),
                isPresented: $viewModel.showCollectionHint
            ) {
                Button(String(localized: "action.ok", defaultValue: "OK"), role: .cancel) {}
            } message: {
                Text(
                    String(
                        localized: "today.collectionHint.message",
                        defaultValue: "Use the Collection tab to browse, search, and manage everything you have saved."
                    )
                )
            }
            .onAppear {
                viewModel.refresh(entries: visibleEntries)
            }
        }
    }

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.xs) {
            Text(EvidenceTheme.tagline)
                .font(.evidenceTitle(24))
                .foregroundStyle(EvidenceFallbackColors.ink)
            Text(
                String(
                    localized: "today.intro",
                    defaultValue: "When it is hard to remember your value, return to evidence you chose."
                )
            )
            .font(.evidenceBody())
            .foregroundStyle(EvidenceFallbackColors.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func todayDestination(_ route: AppRoute) -> some View {
        switch route {
        case .checkIn:
            CheckInFlowView()
        case .recommendation:
            RecommendationView(mode: .fromCheckIn)
        case .grounding:
            RecommendationView(mode: .standaloneGrounding)
        case .entryEditor(let presentation):
            EntryEditorView(presentation: presentation)
        case .entryDetail(let id):
            EntryDetailView(entryID: id)
        case .safetySupport(let state):
            SafetyFlowView(state: state)
        default:
            Text(String(localized: "error.unavailable", defaultValue: "This screen is unavailable."))
        }
    }
}

@Observable
@MainActor
final class TodayViewModel {
    var showCollectionHint = false

    func refresh(entries: [EvidenceEntry]) {
        _ = entries
    }

    /// Soft suggestion: prefer favorites, never random nostalgia.
    func gentleSuggestion(from entries: [EvidenceEntry]) -> EvidenceEntry? {
        let eligible = entries.filter { $0.isEligibleForCheckIn && $0.hasRequiredMeaningAnswer }
        if let favorite = eligible.first(where: \.isFavorite) {
            return favorite
        }
        return eligible.first
    }
}
