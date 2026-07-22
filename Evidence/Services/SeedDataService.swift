import Foundation
import SwiftData

/// Seeds system tags, guided content, and optional DEBUG sample entries.
protocol SeedDataServing: Sendable {
    func seedIfNeeded(context: ModelContext) throws
    func loadGuidedContent(bundle: Bundle) throws -> [GuidedContentItem]
}

enum SampleData {
    /// Debug-only personal samples. Never enabled in production Release by default.
    static var enabled: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-EvidenceSeedSampleData") {
            return true
        }
        if ProcessInfo.processInfo.environment["EVIDENCE_SEED_SAMPLE_DATA"] == "1" {
            return true
        }
        return false
        #else
        return false
        #endif
    }
}

struct SeedDataService: SeedDataServing {
    var dateProvider: any DateProviding = SystemDateProvider()
    var uuidProvider: any UUIDProviding = SystemUUIDProvider()

    func loadGuidedContent(bundle: Bundle = .main) throws -> [GuidedContentItem] {
        try GuidedContentItem.load(from: bundle)
    }

    func seedIfNeeded(context: ModelContext) throws {
        try seedSystemTags(context: context)
        try seedGuidedContentRecords(context: context)
        if SampleData.enabled {
            try seedDebugSampleEntries(context: context)
        }
        try context.save()
    }

    // MARK: - System tags

    private func seedSystemTags(context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<EvidenceTag>())
        let existingKeys = Set(existing.map { "\($0.tagType.rawValue)|\($0.name.lowercased())" })

        func insertIfNeeded(tag: EvidenceTag) {
            let key = "\(tag.tagType.rawValue)|\(tag.name.lowercased())"
            guard !existingKeys.contains(key) else { return }
            context.insert(tag)
        }

        for emotion in Emotion.allCases {
            insertIfNeeded(tag: .systemEmotion(emotion))
        }
        for need in SupportNeed.allCases {
            insertIfNeeded(tag: .systemSupportNeed(need))
        }
        for strength in Strength.allCases {
            insertIfNeeded(tag: .systemStrength(strength))
        }
    }

    // MARK: - Guided content

    private func seedGuidedContentRecords(context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<GuidedContentRecord>())
        let existingIDs = Set(existing.map(\.id))

        let items: [GuidedContentItem]
        if let bundled = try? loadGuidedContent() {
            items = bundled
        } else {
            items = Self.embeddedGuidedContent
        }

        for item in items {
            if existingIDs.contains(item.id) {
                if let record = existing.first(where: { $0.id == item.id }), record.version < item.version {
                    record.title = item.title
                    record.body = item.body
                    record.contentType = item.contentType
                    record.supportedEmotions = item.supportedEmotions
                    record.supportedNeeds = item.supportedNeeds
                    record.isActive = item.isActive
                    record.version = item.version
                    record.touch(dateProvider.now)
                }
                continue
            }
            context.insert(GuidedContentRecord(item: item))
        }
    }

    // MARK: - Debug samples

    private func seedDebugSampleEntries(context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<EvidenceEntry>())
        guard existing.filter(\.userAuthored).isEmpty else { return }

        let tags = try context.fetch(FetchDescriptor<EvidenceTag>())
        func tag(named name: String, type: TagType) -> EvidenceTag? {
            tags.first { $0.tagType == type && $0.name.caseInsensitiveCompare(name) == .orderedSame }
        }

        let samples: [(title: String, body: String, meaning: String, emotion: Emotion, need: SupportNeed)] = [
            (
                "Thank you for listening",
                "A short note from a friend after a hard week.",
                MeaningSuggestion.someoneBelievedInMe.displayName,
                .lonely,
                .evidenceOfConnection
            ),
            (
                "I finished the project",
                "Evidence that I can complete difficult work.",
                MeaningSuggestion.iAccomplishedSomethingDifficult.displayName,
                .selfCritical,
                .evidenceOfCapability
            ),
            (
                "I got through that day",
                "A reminder that overwhelming moments can pass.",
                MeaningSuggestion.iGotThroughSomethingHard.displayName,
                .overwhelmed,
                .grounding
            )
        ]

        for sample in samples {
            let entry = EvidenceEntry(
                title: sample.title,
                bodyText: sample.body,
                entryType: .text,
                sourceType: .self,
                importMethod: .seed,
                meaningPromptAnswer: sample.meaning,
                syncStatus: .localOnly
            )
            context.insert(entry)
            if let emotionTag = tag(named: sample.emotion.displayName, type: .emotion) {
                context.insert(EvidenceEntryTag(entry: entry, tag: emotionTag))
            }
            if let needTag = tag(named: sample.need.displayName, type: .supportNeed) {
                context.insert(EvidenceEntryTag(entry: entry, tag: needTag))
            }
        }
    }

    /// Fallback guided items when JSON is unavailable (mirrors GuidedContent.json).
    static var embeddedGuidedContent: [GuidedContentItem] {
        // Stable IDs so re-seeds update in place.
        let ids: [UUID] = (1...24).compactMap { index in
            UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index))
        }
        guard ids.count == 24 else { return [] }

        return [
            GuidedContentItem(id: ids[0], title: "Not the whole story", body: "A difficult moment is not a complete account of who I am.", contentType: .groundedAffirmation, supportedEmotions: [.down, .ashamed, .selfCritical], supportedNeeds: [.perspective, .reassurance]),
            GuidedContentItem(id: ids[1], title: "Feelings and decisions", body: "My feelings deserve attention, but they do not have to make every decision.", contentType: .groundedAffirmation, supportedEmotions: [.anxious, .overwhelmed, .uncertain], supportedNeeds: [.perspective, .grounding]),
            GuidedContentItem(id: ids[2], title: "Uncertain and careful", body: "I can be uncertain and still take one careful step.", contentType: .groundedAffirmation, supportedEmotions: [.uncertain, .anxious], supportedNeeds: [.oneSmallStep, .reassurance]),
            GuidedContentItem(id: ids[3], title: "Reassurance is allowed", body: "Needing reassurance does not make me weak.", contentType: .groundedAffirmation, supportedEmotions: [.anxious, .lonely, .selfCritical], supportedNeeds: [.reassurance, .evidenceOfConnection]),
            GuidedContentItem(id: ids[4], title: "Doubt is not erasure", body: "My present self-doubt does not erase past evidence of capability.", contentType: .groundedAffirmation, supportedEmotions: [.selfCritical, .ashamed], supportedNeeds: [.evidenceOfCapability, .perspective]),
            GuidedContentItem(id: ids[5], title: "I have survived before", body: "I have survived moments that once felt impossible.", contentType: .groundedAffirmation, supportedEmotions: [.overwhelmed, .down, .anxious], supportedNeeds: [.evidenceOfGrowth, .reassurance]),
            GuidedContentItem(id: ids[6], title: "Speak as a friend", body: "What would I say to someone I care about in this situation?", contentType: .reflectionPrompt, supportedEmotions: [.selfCritical, .ashamed, .lonely], supportedNeeds: [.perspective, .quietReflection]),
            GuidedContentItem(id: ids[7], title: "Known and predicted", body: "What part of this situation is known, and what part am I predicting?", contentType: .reflectionPrompt, supportedEmotions: [.anxious, .uncertain], supportedNeeds: [.perspective, .grounding]),
            GuidedContentItem(id: ids[8], title: "Delay big decisions", body: "Delay a major decision until you feel steadier.", contentType: .manageableAction, supportedEmotions: [.overwhelmed, .anxious, .angry], supportedNeeds: [.oneSmallStep, .grounding]),
            GuidedContentItem(id: ids[9], title: "Five-minute action", body: "Complete one action that takes less than five minutes.", contentType: .manageableAction, supportedEmotions: [.overwhelmed, .down, .numb], supportedNeeds: [.oneSmallStep]),
            GuidedContentItem(id: ids[10], title: "Feet on the floor", body: "Feel your feet on the floor. Name five things you can see, four you can touch, three you can hear.", contentType: .groundingExercise, supportedEmotions: [.anxious, .overwhelmed, .numb], supportedNeeds: [.grounding]),
            GuidedContentItem(id: ids[11], title: "Slow exhale", body: "Breathe in gently for a count of four, and out for a count of six. Repeat a few times.", contentType: .groundingExercise, supportedEmotions: [.anxious, .angry, .overwhelmed], supportedNeeds: [.grounding]),
            GuidedContentItem(id: ids[12], title: "Name the feeling", body: "Silently name the feeling you notice, without judging it. Naming can create a little space.", contentType: .groundingExercise, supportedEmotions: [.numb, .overwhelmed, .angry], supportedNeeds: [.grounding, .quietReflection]),
            GuidedContentItem(id: ids[13], title: "Connection still exists", body: "Feeling lonely does not mean I am alone in every part of my life.", contentType: .groundedAffirmation, supportedEmotions: [.lonely], supportedNeeds: [.evidenceOfConnection, .reassurance]),
            GuidedContentItem(id: ids[14], title: "Shame is loud", body: "Shame is loud, but it is not the only voice that knows me.", contentType: .groundedAffirmation, supportedEmotions: [.ashamed, .selfCritical], supportedNeeds: [.reassurance, .perspective]),
            GuidedContentItem(id: ids[15], title: "Growth is uneven", body: "Growth is often uneven. Progress can include difficult days.", contentType: .groundedAffirmation, supportedEmotions: [.down, .selfCritical], supportedNeeds: [.evidenceOfGrowth, .perspective]),
            GuidedContentItem(id: ids[16], title: "One kind message", body: "Send or write one kind message to someone you trust, or to yourself.", contentType: .manageableAction, supportedEmotions: [.lonely, .down], supportedNeeds: [.evidenceOfConnection, .oneSmallStep]),
            GuidedContentItem(id: ids[17], title: "Drink water", body: "Pause for a glass of water and a short stretch before returning to the problem.", contentType: .manageableAction, supportedEmotions: [.overwhelmed, .anxious], supportedNeeds: [.oneSmallStep, .grounding]),
            GuidedContentItem(id: ids[18], title: "What helped before", body: "What helped even a little the last time I felt something similar?", contentType: .reflectionPrompt, supportedEmotions: [.anxious, .down, .overwhelmed], supportedNeeds: [.perspective, .evidenceOfCapability]),
            GuidedContentItem(id: ids[19], title: "Worthy of care", body: "I am allowed to need care, even when I feel undeserving of it.", contentType: .groundedAffirmation, supportedEmotions: [.ashamed, .lonely, .selfCritical], supportedNeeds: [.reassurance]),
            GuidedContentItem(id: ids[20], title: "Hold the moment lightly", body: "This intensity is real, and it may also change. I can hold this moment without deciding everything from inside it.", contentType: .groundedAffirmation, supportedEmotions: [.overwhelmed, .angry, .anxious], supportedNeeds: [.perspective, .grounding]),
            GuidedContentItem(id: ids[21], title: "Body check-in", body: "Notice your shoulders, jaw, and hands. Soften one place that is holding tension.", contentType: .groundingExercise, supportedEmotions: [.anxious, .angry, .overwhelmed], supportedNeeds: [.grounding]),
            GuidedContentItem(id: ids[22], title: "Write what is observed", body: "Write one sentence about what you directly observed, separate from what you fear may be happening.", contentType: .reflectionPrompt, supportedEmotions: [.anxious, .uncertain], supportedNeeds: [.perspective, .grounding]),
            GuidedContentItem(id: ids[23], title: "Quiet pause", body: "Sit quietly for one minute. You do not need to solve anything during this pause.", contentType: .groundingExercise, supportedEmotions: [.overwhelmed, .numb, .down], supportedNeeds: [.quietReflection, .grounding])
        ]
    }
}
