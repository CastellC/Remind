import SwiftUI
import SwiftData
import UIKit

struct CollectionView: View {
    @Environment(AppContainer.self) private var container
    @Query(sort: \EvidenceEntry.updatedAt, order: .reverse) private var allEntries: [EvidenceEntry]
    @Query(sort: \CategoryModel.sortOrder) private var categories: [CategoryModel]

    @State private var viewModel = CollectionViewModel()
    @State private var path = NavigationPath()
    @State private var showFilters = false

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if filteredEntries.isEmpty {
                    EmptyStateView(
                        title: emptyTitle,
                        message: emptyMessage,
                        systemImage: "square.stack.3d.up",
                        actionTitle: String(localized: "collection.add", defaultValue: "Add evidence"),
                        action: { path.append(AppRoute.entryEditor(.create)) }
                    )
                    .padding()
                } else {
                    List {
                        ForEach(filteredEntries, id: \.id) { entry in
                            NavigationLink(value: AppRoute.entryDetail(entry.id)) {
                                EvidenceCard(
                                    title: entry.title,
                                    meaningSnippet: entry.meaningPromptAnswer,
                                    entryType: entry.entryType,
                                    isFavorite: entry.isFavorite,
                                    showsFavoriteControl: false
                                )
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if entry.isArchived {
                                    Button(String(localized: "action.restore", defaultValue: "Restore")) {
                                        Task { await viewModel.restore(entry.id, container: container) }
                                    }
                                    .tint(EvidenceFallbackColors.accent)
                                } else {
                                    Button(String(localized: "action.archive", defaultValue: "Archive")) {
                                        Task { await viewModel.archive(entry.id, container: container) }
                                    }
                                    .tint(.orange)
                                }
                                Button(String(localized: "action.favorite", defaultValue: "Favorite")) {
                                    Task { await viewModel.toggleFavorite(entry, container: container) }
                                }
                                .tint(.pink)
                            }
                            .contextMenu {
                                Button(entry.isFavorite ? String(localized: "action.unfavorite", defaultValue: "Remove favorite") : String(localized: "action.favorite", defaultValue: "Favorite")) {
                                    Task { await viewModel.toggleFavorite(entry, container: container) }
                                }
                                Button(entry.isArchived ? String(localized: "action.restore", defaultValue: "Restore") : String(localized: "action.archive", defaultValue: "Archive")) {
                                    Task {
                                        if entry.isArchived {
                                            await viewModel.restore(entry.id, container: container)
                                        } else {
                                            await viewModel.archive(entry.id, container: container)
                                        }
                                    }
                                }
                                Button(String(localized: "action.edit", defaultValue: "Edit")) {
                                    path.append(AppRoute.entryEditor(.edit(entry.id)))
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(String(localized: "collection.title", defaultValue: "Your collection"))
            .searchable(
                text: $viewModel.searchText,
                prompt: String(localized: "collection.search", defaultValue: "Search your collection")
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showFilters = true
                    } label: {
                        Label(
                            viewModel.activeFilterCount == 0
                                ? String(localized: "collection.filters", defaultValue: "Filters")
                                : String(localized: "collection.filters.count", defaultValue: "Filters (\(viewModel.activeFilterCount))"),
                            systemImage: "line.3.horizontal.decrease.circle"
                        )
                    }
                    .accessibilityValue("\(viewModel.activeFilterCount) active")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(String(localized: "collection.add", defaultValue: "Add evidence")) {
                            path.append(AppRoute.entryEditor(.create))
                        }
                        Button(String(localized: "collection.categories", defaultValue: "Manage categories")) {
                            path.append(AppRoute.categoryManager)
                        }
                        Button(String(localized: "collection.archived", defaultValue: "Archived entries")) {
                            path.append(AppRoute.archivedEntries)
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                            .accessibilityLabel(String(localized: "collection.more", defaultValue: "Collection actions"))
                    }
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                collectionDestination(route)
            }
            .sheet(isPresented: $showFilters) {
                NavigationStack {
                    CollectionFiltersView(viewModel: viewModel, categories: categories)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(String(localized: "action.done", defaultValue: "Done")) {
                                    showFilters = false
                                }
                            }
                            ToolbarItem(placement: .destructiveAction) {
                                Button(String(localized: "collection.clearFilters", defaultValue: "Clear")) {
                                    viewModel.clearFilters()
                                }
                                .disabled(viewModel.activeFilterCount == 0)
                            }
                        }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var filteredEntries: [EvidenceEntry] {
        viewModel.filtered(from: allEntries, showArchivedOnly: false)
    }

    private var emptyTitle: String {
        if viewModel.activeFilterCount > 0 || !viewModel.searchText.isEmpty {
            return String(localized: "collection.empty.filtered.title", defaultValue: "No matches")
        }
        return String(localized: "collection.empty.title", defaultValue: "Nothing saved yet")
    }

    private var emptyMessage: String {
        if viewModel.activeFilterCount > 0 || !viewModel.searchText.isEmpty {
            return String(localized: "collection.empty.filtered.message", defaultValue: "Try clearing filters or searching for different words.")
        }
        return String(localized: "collection.empty.message", defaultValue: "Add evidence you may need when it is hard to remember what is true.")
    }

    @ViewBuilder
    private func collectionDestination(_ route: AppRoute) -> some View {
        switch route {
        case .entryDetail(let id):
            EntryDetailView(entryID: id)
        case .entryEditor(let presentation):
            EntryEditorView(presentation: presentation)
        case .categoryManager:
            CategoryManagerView()
        case .archivedEntries:
            ArchivedEntriesView()
        default:
            Text(String(localized: "error.unavailable", defaultValue: "This screen is unavailable."))
        }
    }
}

@Observable
@MainActor
final class CollectionViewModel {
    var searchText = ""
    var filterEntryType: EntryType?
    var filterEmotion: Emotion?
    var filterSupportNeed: SupportNeed?
    var filterStrength: Strength?
    var filterCategoryID: UUID?
    var filterSourceType: SourceType?
    var filterFavoriteOnly = false
    var filterSensitiveOnly = false
    var filterSyncStatus: SyncStatus?

    var activeFilterCount: Int {
        var count = 0
        if filterEntryType != nil { count += 1 }
        if filterEmotion != nil { count += 1 }
        if filterSupportNeed != nil { count += 1 }
        if filterStrength != nil { count += 1 }
        if filterCategoryID != nil { count += 1 }
        if filterSourceType != nil { count += 1 }
        if filterFavoriteOnly { count += 1 }
        if filterSensitiveOnly { count += 1 }
        if filterSyncStatus != nil { count += 1 }
        return count
    }

    func clearFilters() {
        filterEntryType = nil
        filterEmotion = nil
        filterSupportNeed = nil
        filterStrength = nil
        filterCategoryID = nil
        filterSourceType = nil
        filterFavoriteOnly = false
        filterSensitiveOnly = false
        filterSyncStatus = nil
    }

    func filtered(from entries: [EvidenceEntry], showArchivedOnly: Bool) -> [EvidenceEntry] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return entries.filter { entry in
            guard entry.deletedAt == nil, !entry.pendingDeletion else { return false }
            if showArchivedOnly {
                guard entry.isArchived else { return false }
            } else {
                guard !entry.isArchived else { return false }
            }
            if let filterEntryType, entry.entryType != filterEntryType { return false }
            if let filterSourceType, entry.sourceType != filterSourceType { return false }
            if let filterSyncStatus, entry.syncStatus != filterSyncStatus { return false }
            if filterFavoriteOnly, !entry.isFavorite { return false }
            if filterSensitiveOnly, !entry.isSensitive { return false }
            if let filterCategoryID {
                guard entry.categories.contains(where: { $0.id == filterCategoryID }) else { return false }
            }
            if let filterEmotion {
                let names = entry.tags.filter { $0.tagType == .emotion }.map { $0.name.lowercased() }
                guard names.contains(filterEmotion.displayName.lowercased()) else { return false }
            }
            if let filterSupportNeed {
                let names = entry.tags.filter { $0.tagType == .supportNeed }.map { $0.name.lowercased() }
                guard names.contains(filterSupportNeed.displayName.lowercased()) else { return false }
            }
            if let filterStrength {
                let names = entry.tags.filter { $0.tagType == .strength }.map { $0.name.lowercased() }
                guard names.contains(filterStrength.displayName.lowercased()) else { return false }
            }
            if !needle.isEmpty {
                let haystacks: [String] = [
                    entry.title,
                    entry.bodyText ?? "",
                    entry.meaningPromptAnswer,
                    entry.sourceName ?? "",
                    entry.categories.map(\.name).joined(separator: " "),
                    entry.tags.map(\.name).joined(separator: " ")
                ]
                guard haystacks.joined(separator: " ").lowercased().contains(needle) else { return false }
            }
            return true
        }
    }

    func archive(_ id: UUID, container: AppContainer) async {
        try? await container.entryRepository.archive(id: id)
    }

    func restore(_ id: UUID, container: AppContainer) async {
        try? await container.entryRepository.restore(id: id)
    }

    func toggleFavorite(_ entry: EvidenceEntry, container: AppContainer) async {
        entry.isFavorite.toggle()
        entry.touch()
        try? await container.entryRepository.save(entry)
    }
}

struct CollectionFiltersView: View {
    @Bindable var viewModel: CollectionViewModel
    let categories: [CategoryModel]

    var body: some View {
        Form {
            Section(String(localized: "filter.type", defaultValue: "Entry type")) {
                Picker(selection: $viewModel.filterEntryType) {
                    Text(String(localized: "filter.any", defaultValue: "Any")).tag(Optional<EntryType>.none)
                    ForEach(EntryType.allCases) { type in
                        Text(type.displayName).tag(Optional(type))
                    }
                } label: {
                    Text(String(localized: "filter.type", defaultValue: "Entry type"))
                }
            }
            Section(String(localized: "filter.emotion", defaultValue: "Emotion")) {
                Picker(selection: $viewModel.filterEmotion) {
                    Text(String(localized: "filter.any", defaultValue: "Any")).tag(Optional<Emotion>.none)
                    ForEach(Emotion.allCases) { emotion in
                        Text(emotion.displayName).tag(Optional(emotion))
                    }
                } label: {
                    Text(String(localized: "filter.emotion", defaultValue: "Emotion"))
                }
            }
            Section(String(localized: "filter.need", defaultValue: "Support need")) {
                Picker(selection: $viewModel.filterSupportNeed) {
                    Text(String(localized: "filter.any", defaultValue: "Any")).tag(Optional<SupportNeed>.none)
                    ForEach(SupportNeed.allCases) { need in
                        Text(need.displayName).tag(Optional(need))
                    }
                } label: {
                    Text(String(localized: "filter.need", defaultValue: "Support need"))
                }
            }
            Section(String(localized: "filter.strength", defaultValue: "Strength")) {
                Picker(selection: $viewModel.filterStrength) {
                    Text(String(localized: "filter.any", defaultValue: "Any")).tag(Optional<Strength>.none)
                    ForEach(Strength.allCases) { strength in
                        Text(strength.displayName).tag(Optional(strength))
                    }
                } label: {
                    Text(String(localized: "filter.strength", defaultValue: "Strength"))
                }
            }
            Section(String(localized: "filter.category", defaultValue: "Category")) {
                Picker(selection: $viewModel.filterCategoryID) {
                    Text(String(localized: "filter.any", defaultValue: "Any")).tag(Optional<UUID>.none)
                    ForEach(categories, id: \.id) { category in
                        Text(category.name).tag(Optional(category.id))
                    }
                } label: {
                    Text(String(localized: "filter.category", defaultValue: "Category"))
                }
            }
            Section(String(localized: "filter.source", defaultValue: "Source")) {
                Picker(selection: $viewModel.filterSourceType) {
                    Text(String(localized: "filter.any", defaultValue: "Any")).tag(Optional<SourceType>.none)
                    ForEach(SourceType.allCases) { source in
                        Text(source.displayName).tag(Optional(source))
                    }
                } label: {
                    Text(String(localized: "filter.source", defaultValue: "Source"))
                }
            }
            Section(String(localized: "filter.sync", defaultValue: "Sync status")) {
                Picker(selection: $viewModel.filterSyncStatus) {
                    Text(String(localized: "filter.any", defaultValue: "Any")).tag(Optional<SyncStatus>.none)
                    ForEach(SyncStatus.allCases) { status in
                        Text(status.displayName).tag(Optional(status))
                    }
                } label: {
                    Text(String(localized: "filter.sync", defaultValue: "Sync status"))
                }
            }
            Section {
                Toggle(String(localized: "filter.favorites", defaultValue: "Favorites only"), isOn: $viewModel.filterFavoriteOnly)
                Toggle(String(localized: "filter.sensitive", defaultValue: "Sensitive only"), isOn: $viewModel.filterSensitiveOnly)
            }
        }
        .navigationTitle(String(localized: "collection.filters", defaultValue: "Filters"))
    }
}

struct ArchivedEntriesView: View {
    @Environment(AppContainer.self) private var container
    @Query(filter: #Predicate<EvidenceEntry> { $0.isArchived == true }, sort: \EvidenceEntry.updatedAt, order: .reverse)
    private var archived: [EvidenceEntry]
    @State private var viewModel = CollectionViewModel()

    var body: some View {
        List {
            ForEach(archived.filter { $0.deletedAt == nil }, id: \.id) { entry in
                NavigationLink(value: AppRoute.entryDetail(entry.id)) {
                    EvidenceCard(title: entry.title, meaningSnippet: entry.meaningPromptAnswer, entryType: entry.entryType, showsFavoriteControl: false)
                }
                .swipeActions {
                    Button(String(localized: "action.restore", defaultValue: "Restore")) {
                        Task { await viewModel.restore(entry.id, container: container) }
                    }
                    .tint(EvidenceFallbackColors.accent)
                }
            }
        }
        .navigationTitle(String(localized: "collection.archived", defaultValue: "Archived entries"))
        .navigationDestination(for: AppRoute.self) { route in
            if case .entryDetail(let id) = route {
                EntryDetailView(entryID: id)
            }
        }
        .overlay {
            if archived.isEmpty {
                EmptyStateView(
                    title: String(localized: "collection.archived.empty.title", defaultValue: "No archived entries"),
                    message: String(localized: "collection.archived.empty.message", defaultValue: "Archived items move here until you restore them."),
                    systemImage: "archivebox"
                )
            }
        }
    }
}

import SwiftUI
import SwiftData
import UIKit

struct EntryDetailView: View {
    @Environment(AppContainer.self) private var container
    let entryID: UUID

    @State private var entry: EvidenceEntry?
    @State private var image: UIImage?
    @State private var editorPresentation: EntryEditorPresentation?
    @State private var confirmDelete = false

    var body: some View {
        Group {
            if let entry {
                ScrollView {
                    VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.md) {
                        Text(entry.title)
                            .font(.evidenceTitle(26))
                            .accessibilityAddTraits(.isHeader)

                        if entry.entryType == .image || entry.localImageFileName != nil {
                            if let image {
                                AccessibleImageView(
                                    uiImage: image,
                                    accessibilityDescription: entry.accessibilityDescription
                                )
                            } else {
                                AccessibleImageView.placeholder(
                                    accessibilityDescription: entry.accessibilityDescription
                                )
                            }
                        }

                        if let body = entry.bodyText, !body.isEmpty {
                            Text(body)
                                .font(.evidenceBody())
                        }

                        VStack(alignment: .leading, spacing: EvidenceTheme.Spacing.xs) {
                            Text(MeaningSuggestion.promptQuestion)
                                .font(.evidenceCaption().weight(.semibold))
                                .foregroundStyle(EvidenceFallbackColors.muted)
                            Text(entry.meaningPromptAnswer)
                                .font(.evidenceBody().weight(.medium))
                        }

                        if let source = entry.sourceName, !source.isEmpty {
                            Text("\(entry.sourceType.displayName): \(source)")
                                .font(.evidenceCaption())
                                .foregroundStyle(EvidenceFallbackColors.muted)
                        }

                        FlowTagList(tags: entry.tags.map(\.name))
                        SyncStatusView(status: entry.syncStatus)

                        PrimaryButton(title: String(localized: "action.edit", defaultValue: "Edit")) {
                            editorPresentation = .edit(entry.id)
                        }
                        SecondaryButton(
                            title: entry.isArchived
                                ? String(localized: "action.restore", defaultValue: "Restore")
                                : String(localized: "action.archive", defaultValue: "Archive")
                        ) {
                            Task {
                                if entry.isArchived {
                                    try? await container.entryRepository.restore(id: entry.id)
                                } else {
                                    try? await container.entryRepository.archive(id: entry.id)
                                }
                                await reload()
                            }
                        }
                        SecondaryButton(
                            title: String(localized: "action.delete", defaultValue: "Delete"),
                            action: { confirmDelete = true }
                        )
                    }
                    .padding(EvidenceTheme.Spacing.lg)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(String(localized: "entry.detail.nav", defaultValue: "Evidence"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $editorPresentation) { presentation in
            EntryEditorView(presentation: presentation)
        }
        .task { await reload() }
        .confirmationDialog(
            String(localized: "entry.delete.title", defaultValue: "Delete this evidence?"),
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button(String(localized: "action.delete", defaultValue: "Delete"), role: .destructive) {
                Task {
                    try? await container.entryRepository.markPendingDeletion(id: entryID)
                    try? await container.entryRepository.deletePermanently(id: entryID)
                }
            }
            Button(String(localized: "action.cancel", defaultValue: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "entry.delete.message", defaultValue: "This removes the item from your collection. This cannot be undone on this device."))
        }
    }

    private func reload() async {
        entry = try? await container.entryRepository.fetch(id: entryID)
        if let fileName = entry?.localImageFileName, let storage = container.imageStorage {
            image = try? await storage.loadDisplayImage(fileName: fileName)
        }
    }
}

struct FlowTagList: View {
    let tags: [String]

    var body: some View {
        FlexibleWrap {
            ForEach(tags, id: \.self) { tag in
                TagChip(title: tag)
            }
        }
    }
}

/// Simple wrapping layout for chips without external dependencies.
struct FlexibleWrap<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        // Use a LazyVGrid with adaptive columns as a calm wrap approximation.
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 90), spacing: EvidenceTheme.Spacing.xs)],
            alignment: .leading,
            spacing: EvidenceTheme.Spacing.xs
        ) {
            content
        }
    }
}
