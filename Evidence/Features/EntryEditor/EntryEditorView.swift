import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct EntryEditorView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CategoryModel.sortOrder) private var categories: [CategoryModel]
    @Query private var allTags: [EvidenceTag]

    let presentation: EntryEditorPresentation
    var onSaved: (() -> Void)? = nil

    @State private var viewModel = EntryEditorViewModel()
    @State private var photoItem: PhotosPickerItem?
    @State private var validationMessage: String?
    @State private var isSaving = false

    var body: some View {
        Form {
            Section {
                Picker(
                    String(localized: "editor.type", defaultValue: "How to add evidence"),
                    selection: $viewModel.entryType
                ) {
                    ForEach(EntryType.allCases.filter { !$0.isSystemContent }) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                TextField(
                    String(localized: "editor.title", defaultValue: "Title or short label"),
                    text: $viewModel.title
                )
                TextField(
                    String(localized: "editor.body", defaultValue: "Words to remember"),
                    text: $viewModel.bodyText,
                    axis: .vertical
                )
                .lineLimit(3...8)
            }

            if viewModel.entryType == .image {
                Section(
                    String(localized: "editor.image", defaultValue: "Image"),
                    footer: Text(String(localized: "editor.image.meaningHint", defaultValue: "Describe what this image means to you in the meaning section below."))
                ) {
                    PhotosPicker(
                        selection: $photoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(
                            viewModel.pickedImage == nil
                                ? String(localized: "editor.image.pick", defaultValue: "Choose photo")
                                : String(localized: "editor.image.change", defaultValue: "Change photo"),
                            systemImage: "photo"
                        )
                    }
                    if let picked = viewModel.pickedImage {
                        AccessibleImageView(
                            uiImage: picked,
                            accessibilityDescription: viewModel.accessibilityDescription
                        )
                        .frame(maxHeight: 220)
                    }
                    TextField(
                        String(localized: "editor.image.a11y", defaultValue: "Image description for VoiceOver"),
                        text: $viewModel.accessibilityDescription,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                }
            }

            Section(
                MeaningSuggestion.promptQuestion,
                footer: Text(String(localized: "editor.meaning.required", defaultValue: "Required for personal entries. Future you needs to know why this matters."))
            ) {
                ForEach(MeaningSuggestion.allCases) { suggestion in
                    SupportNeedStyleRow(
                        title: suggestion.displayName,
                        isSelected: viewModel.selectedMeaning == suggestion
                    ) {
                        viewModel.selectedMeaning = suggestion
                        if !suggestion.expectsCustomText {
                            viewModel.customMeaning = suggestion.displayName
                        } else if viewModel.customMeaning == viewModel.selectedMeaning?.displayName {
                            viewModel.customMeaning = ""
                        }
                    }
                }
                if viewModel.selectedMeaning?.expectsCustomText == true || viewModel.selectedMeaning == nil {
                    TextField(
                        String(localized: "editor.meaning.custom", defaultValue: "Your own explanation"),
                        text: $viewModel.customMeaning,
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                }
            }

            Section(
                String(localized: "editor.tags", defaultValue: "When it may help"),
                footer: Text(String(localized: "editor.tags.required", defaultValue: "Choose at least one emotion or support need."))
            ) {
                Text(String(localized: "editor.emotions", defaultValue: "Emotions"))
                    .font(.evidenceCaption().weight(.semibold))
                FlexibleWrap {
                    ForEach(Emotion.allCases) { emotion in
                        TagChip(
                            title: emotion.displayName,
                            isSelected: viewModel.emotions.contains(emotion),
                            systemImage: emotion.symbolName,
                            onTap: { viewModel.toggleEmotion(emotion) }
                        )
                    }
                }
                Text(String(localized: "editor.needs", defaultValue: "Support needs"))
                    .font(.evidenceCaption().weight(.semibold))
                FlexibleWrap {
                    ForEach(SupportNeed.allCases) { need in
                        TagChip(
                            title: need.displayName,
                            isSelected: viewModel.supportNeeds.contains(need),
                            systemImage: need.symbolName,
                            onTap: { viewModel.toggleNeed(need) }
                        )
                    }
                }
            }

            Section(String(localized: "editor.optional", defaultValue: "Optional details")) {
                Picker(String(localized: "editor.sourceType", defaultValue: "Source"), selection: $viewModel.sourceType) {
                    ForEach(SourceType.allCases) { source in
                        Text(source.displayName).tag(source)
                    }
                }
                TextField(String(localized: "editor.sourceName", defaultValue: "Source name"), text: $viewModel.sourceName)
                TextField(String(localized: "editor.sourceContext", defaultValue: "Source context"), text: $viewModel.sourceContext)
                TextField(String(localized: "editor.url", defaultValue: "Original URL"), text: $viewModel.originalURLString)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                DatePicker(
                    String(localized: "editor.occurred", defaultValue: "Date it occurred"),
                    selection: Binding(
                        get: { viewModel.occurredAt ?? Date() },
                        set: { viewModel.occurredAt = $0 }
                    ),
                    displayedComponents: .date
                )
                Toggle(String(localized: "editor.hasOccurred", defaultValue: "Include occurred date"), isOn: Binding(
                    get: { viewModel.occurredAt != nil },
                    set: { viewModel.occurredAt = $0 ? (viewModel.occurredAt ?? Date()) : nil }
                ))
                Toggle(String(localized: "editor.meaningfulDate", defaultValue: "Remind me around a meaningful date"), isOn: $viewModel.hasMeaningfulDate)
                if viewModel.hasMeaningfulDate {
                    DatePicker(
                        String(localized: "editor.meaningfulDate.picker", defaultValue: "Meaningful date"),
                        selection: $viewModel.meaningfulDate,
                        displayedComponents: .date
                    )
                }
                Text(String(localized: "editor.strengths", defaultValue: "Strengths"))
                    .font(.evidenceCaption().weight(.semibold))
                FlexibleWrap {
                    ForEach(Strength.allCases) { strength in
                        TagChip(
                            title: strength.displayName,
                            isSelected: viewModel.strengths.contains(strength),
                            onTap: { viewModel.toggleStrength(strength) }
                        )
                    }
                }
                if !categories.isEmpty {
                    Text(String(localized: "editor.categories", defaultValue: "Categories"))
                        .font(.evidenceCaption().weight(.semibold))
                    FlexibleWrap {
                        ForEach(categories, id: \.id) { category in
                            TagChip(
                            title: category.name,
                            isSelected: viewModel.categoryIDs.contains(category.id),
                            systemImage: category.iconName,
                            onTap: { viewModel.toggleCategory(category.id) }
                        )
                        }
                    }
                }
            }

            Section(String(localized: "editor.privacy", defaultValue: "Privacy and display")) {
                Toggle(String(localized: "editor.favorite", defaultValue: "Favorite"), isOn: $viewModel.isFavorite)
                Toggle(String(localized: "editor.sensitive", defaultValue: "Sensitive content"), isOn: $viewModel.isSensitive)
                Toggle(String(localized: "editor.excludeCheckIns", defaultValue: "Exclude from check-ins"), isOn: $viewModel.excludeFromCheckIns)
                Toggle(String(localized: "editor.excludeNotifications", defaultValue: "Exclude from notifications"), isOn: $viewModel.excludeFromNotifications)
            }

            if let validationMessage {
                Section {
                    Text(validationMessage)
                        .font(.evidenceCaption())
                        .foregroundStyle(.orange)
                        .accessibilityLabel(validationMessage)
                }
            }

            Section {
                PrimaryButton(
                    title: String(localized: "action.save", defaultValue: "Save"),
                    isLoading: isSaving
                ) {
                    Task { await save() }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadIfNeeded(presentation: presentation, container: container, allTags: allTags)
        }
        .onChange(of: photoItem) { _, newItem in
            Task { await loadPhoto(newItem) }
        }
    }

    private var navigationTitle: String {
        switch presentation {
        case .create, .firstEntry:
            return String(localized: "editor.nav.new", defaultValue: "Add evidence")
        case .edit:
            return String(localized: "editor.nav.edit", defaultValue: "Edit evidence")
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let picked = try? await item.loadTransferable(type: PickedImageData.self) {
            viewModel.pickedImageData = picked.data
            viewModel.pickedImage = UIImage(data: picked.data)
            if viewModel.entryType != .image {
                viewModel.entryType = .image
            }
        }
    }

    private func save() async {
        validationMessage = viewModel.validationError()
        guard validationMessage == nil else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await viewModel.save(presentation: presentation, container: container, allTags: allTags, categories: categories)
            onSaved?()
            dismiss()
        } catch {
            validationMessage = String(
                localized: "editor.saveFailed",
                defaultValue: "Could not save this entry. Please try again."
            )
        }
    }
}

@Observable
@MainActor
final class EntryEditorViewModel {
    var entryType: EntryType = .text
    var title = ""
    var bodyText = ""
    var selectedMeaning: MeaningSuggestion?
    var customMeaning = ""
    var emotions: Set<Emotion> = []
    var supportNeeds: Set<SupportNeed> = []
    var strengths: Set<Strength> = []
    var categoryIDs: Set<UUID> = []
    var sourceType: SourceType = .self
    var sourceName = ""
    var sourceContext = ""
    var originalURLString = ""
    var occurredAt: Date?
    var hasMeaningfulDate = false
    var meaningfulDate = Date()
    var isFavorite = false
    var isSensitive = false
    var excludeFromCheckIns = false
    var excludeFromNotifications = false
    var accessibilityDescription = ""
    var pickedImage: UIImage?
    var pickedImageData: Data?
    var editingEntryID: UUID?
    var existingImageFileName: String?
    private var didLoad = false

    func loadIfNeeded(presentation: EntryEditorPresentation, container: AppContainer, allTags: [EvidenceTag]) async {
        guard !didLoad else { return }
        didLoad = true
        if case .edit(let id) = presentation {
            editingEntryID = id
            guard let entry = try? await container.entryRepository.fetch(id: id) else { return }
            entryType = entry.entryType
            title = entry.title
            bodyText = entry.bodyText ?? ""
            customMeaning = entry.meaningPromptAnswer
            selectedMeaning = MeaningSuggestion.allCases.first { $0.displayName == entry.meaningPromptAnswer } ?? .somethingElse
            sourceType = entry.sourceType
            sourceName = entry.sourceName ?? ""
            sourceContext = entry.sourceContext ?? ""
            originalURLString = entry.originalURLString ?? ""
            occurredAt = entry.occurredAt
            if let meaningful = entry.meaningfulDate {
                hasMeaningfulDate = true
                meaningfulDate = meaningful
            }
            isFavorite = entry.isFavorite
            isSensitive = entry.isSensitive
            excludeFromCheckIns = entry.excludeFromCheckIns
            excludeFromNotifications = entry.excludeFromNotifications
            accessibilityDescription = entry.accessibilityDescription ?? ""
            existingImageFileName = entry.localImageFileName
            for tag in entry.tags {
                switch tag.tagType {
                case .emotion:
                    if let emotion = Emotion.allCases.first(where: { $0.displayName.caseInsensitiveCompare(tag.name) == .orderedSame }) {
                        emotions.insert(emotion)
                    }
                case .supportNeed:
                    if let need = SupportNeed.allCases.first(where: { $0.displayName.caseInsensitiveCompare(tag.name) == .orderedSame }) {
                        supportNeeds.insert(need)
                    }
                case .strength:
                    if let strength = Strength.allCases.first(where: { $0.displayName.caseInsensitiveCompare(tag.name) == .orderedSame }) {
                        strengths.insert(strength)
                    }
                default:
                    break
                }
            }
            categoryIDs = Set(entry.categories.map(\.id))
            if let fileName = entry.localImageFileName, let storage = container.imageStorage {
                pickedImage = try? await storage.loadDisplayImage(fileName: fileName)
            }
        } else if case .firstEntry = presentation {
            entryType = .text
        }
    }

    func toggleEmotion(_ emotion: Emotion) {
        if emotions.contains(emotion) { emotions.remove(emotion) } else { emotions.insert(emotion) }
    }

    func toggleNeed(_ need: SupportNeed) {
        if supportNeeds.contains(need) { supportNeeds.remove(need) } else { supportNeeds.insert(need) }
    }

    func toggleStrength(_ strength: Strength) {
        if strengths.contains(strength) { strengths.remove(strength) } else { strengths.insert(strength) }
    }

    func toggleCategory(_ id: UUID) {
        if categoryIDs.contains(id) { categoryIDs.remove(id) } else { categoryIDs.insert(id) }
    }

    var resolvedMeaning: String {
        if let selectedMeaning, !selectedMeaning.expectsCustomText {
            return selectedMeaning.displayName
        }
        return customMeaning.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func validationError() -> String? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(localized: "editor.validation.title", defaultValue: "Please add a short title so you can find this later.")
        }
        if resolvedMeaning.isEmpty {
            return String(localized: "editor.validation.meaning", defaultValue: "Please answer “Why might future you need this?” before saving.")
        }
        if emotions.isEmpty && supportNeeds.isEmpty {
            return String(localized: "editor.validation.tags", defaultValue: "Please choose at least one emotion or support need.")
        }
        if entryType == .image && pickedImage == nil && existingImageFileName == nil {
            return String(localized: "editor.validation.image", defaultValue: "Please choose a photo, or switch to a text entry.")
        }
        return nil
    }

    func save(
        presentation: EntryEditorPresentation,
        container: AppContainer,
        allTags: [EvidenceTag],
        categories: [CategoryModel]
    ) async throws {
        let profile = await container.ensureProfile()
        let sync: SyncStatus = profile.cloudSyncEnabled && profile.authenticatedUserID != nil ? .pendingUpload : .localOnly

        var imageFileName = existingImageFileName
        if let data = pickedImageData, let storage = container.imageStorage {
            let stored = try await storage.saveImageData(data)
            imageFileName = stored.displayFileName
        }

        let entry: EvidenceEntry
        if let editingEntryID, let existing = try await container.entryRepository.fetch(id: editingEntryID) {
            entry = existing
        } else {
            entry = EvidenceEntry(
                ownerUserID: profile.authenticatedUserID,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                meaningPromptAnswer: resolvedMeaning,
                syncStatus: sync
            )
        }

        entry.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.bodyText = bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bodyText
        entry.entryType = entryType
        entry.sourceType = sourceType
        entry.sourceName = sourceName.isEmpty ? nil : sourceName
        entry.sourceContext = sourceContext.isEmpty ? nil : sourceContext
        entry.originalURLString = originalURLString.isEmpty ? nil : originalURLString
        entry.occurredAt = occurredAt
        entry.meaningfulDate = hasMeaningfulDate ? meaningfulDate : nil
        entry.isFavorite = isFavorite
        entry.isSensitive = isSensitive
        entry.excludeFromCheckIns = excludeFromCheckIns
        entry.excludeFromNotifications = excludeFromNotifications
        entry.userAuthored = true
        entry.meaningPromptAnswer = resolvedMeaning
        entry.localImageFileName = imageFileName
        entry.accessibilityDescription = accessibilityDescription.isEmpty ? nil : accessibilityDescription
        entry.syncStatus = sync
        entry.touch(container.environment.dateProvider.now)

        try await container.entryRepository.save(entry)

        // Replace tag links
        for link in entry.entryTags {
            container.modelContainer.mainContext.delete(link)
        }
        func attach(tag: EvidenceTag) {
            let link = EvidenceEntryTag(entry: entry, tag: tag)
            container.modelContainer.mainContext.insert(link)
        }
        for emotion in emotions {
            let tag = allTags.first { $0.tagType == .emotion && $0.name.caseInsensitiveCompare(emotion.displayName) == .orderedSame }
                ?? EvidenceTag.systemEmotion(emotion)
            if tag.modelContext == nil {
                container.modelContainer.mainContext.insert(tag)
            }
            attach(tag: tag)
        }
        for need in supportNeeds {
            let tag = allTags.first { $0.tagType == .supportNeed && $0.name.caseInsensitiveCompare(need.displayName) == .orderedSame }
                ?? EvidenceTag.systemSupportNeed(need)
            if tag.modelContext == nil {
                container.modelContainer.mainContext.insert(tag)
            }
            attach(tag: tag)
        }
        for strength in strengths {
            let tag = allTags.first { $0.tagType == .strength && $0.name.caseInsensitiveCompare(strength.displayName) == .orderedSame }
                ?? EvidenceTag.systemStrength(strength)
            if tag.modelContext == nil {
                container.modelContainer.mainContext.insert(tag)
            }
            attach(tag: tag)
        }

        for link in entry.entryCategories {
            container.modelContainer.mainContext.delete(link)
        }
        for category in categories where categoryIDs.contains(category.id) {
            let link = EvidenceEntryCategory(entry: entry, category: category)
            container.modelContainer.mainContext.insert(link)
        }

        if hasMeaningfulDate {
            let existingReminders = (try? await container.meaningfulDateRepository.fetch(forEntryID: entry.id)) ?? []
            if let first = existingReminders.first {
                first.date = meaningfulDate
                first.enabled = true
                first.touch()
                try await container.meaningfulDateRepository.save(first)
            } else {
                let reminder = MeaningfulDateReminder(entry: entry, date: meaningfulDate, recurrence: .yearly)
                try await container.meaningfulDateRepository.save(reminder)
            }
        }

        try container.modelContainer.mainContext.save()
    }
}
