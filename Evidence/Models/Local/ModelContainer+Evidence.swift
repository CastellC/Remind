import Foundation
import SwiftData

extension ModelContainer {
    /// All SwiftData model types used by Evidence.
    static var evidenceModelTypes: [any PersistentModel.Type] {
        [
            AppProfile.self,
            EvidenceEntry.self,
            EvidenceTag.self,
            EvidenceEntryTag.self,
            CategoryModel.self,
            EvidenceEntryCategory.self,
            CheckIn.self,
            RecommendationSession.self,
            RecommendationSessionItem.self,
            RecommendationFeedback.self,
            ReminderSchedule.self,
            MeaningfulDateReminder.self,
            GuidedContentRecord.self
        ]
    }

    static var evidenceSchema: Schema {
        Schema(evidenceModelTypes)
    }

    /// Persistent on-disk container for the running app.
    static func evidence(
        inMemory: Bool = false,
        isStoredInMemoryOnly: Bool? = nil
    ) throws -> ModelContainer {
        let memoryOnly = isStoredInMemoryOnly ?? inMemory
        let configuration = ModelConfiguration(
            "Evidence",
            schema: evidenceSchema,
            isStoredInMemoryOnly: memoryOnly,
            allowsSave: true
        )
        return try ModelContainer(for: evidenceSchema, configurations: [configuration])
    }

    /// In-memory container for unit tests and SwiftUI previews.
    static func evidencePreview(
        seed: ((ModelContext) throws -> Void)? = nil
    ) throws -> ModelContainer {
        let container = try evidence(inMemory: true)
        if let seed {
            let context = ModelContext(container)
            try seed(context)
            try context.save()
        }
        return container
    }

    /// Convenience for `#Preview` blocks.
    @MainActor
    static var evidencePreviewContainer: ModelContainer {
        do {
            return try evidencePreview { context in
                let profile = AppProfile(
                    displayName: "Preview",
                    onboardingCompletedAt: .now,
                    selectedUseCases: [.rememberKindWords, .groundWhenAnxious]
                )
                context.insert(profile)

                let entry = EvidenceEntry(
                    title: "You handled that with care",
                    bodyText: "A note from a friend after a difficult week.",
                    entryType: .text,
                    sourceType: .friend,
                    sourceName: "Alex",
                    meaningPromptAnswer: MeaningSuggestion.someoneBelievedInMe.displayName,
                    syncStatus: .localOnly
                )
                context.insert(entry)

                let capability = EvidenceTag.systemStrength(.capable)
                context.insert(capability)
                context.insert(EvidenceEntryTag(entry: entry, tag: capability))

                let category = CategoryModel(name: "Support", iconName: "heart", sortOrder: 0)
                context.insert(category)
                context.insert(EvidenceEntryCategory(entry: entry, category: category))
            }
        } catch {
            fatalError("Failed to create Evidence preview ModelContainer: \(error)")
        }
    }
}

enum EvidenceModelContainerFactory {
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer.evidence(inMemory: inMemory)
    }

    static func makeForTests() throws -> ModelContainer {
        try ModelContainer.evidence(inMemory: true)
    }
}
