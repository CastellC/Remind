import Foundation

// MARK: - Public result types

/// A scored recommendation ready for presentation.
struct RecommendationResult: Equatable, Sendable {
    let item: RecommendationItem
    let score: Double
    let selectionReason: String
    let matchedTags: [String]
    let isGuided: Bool
}

/// Either a personal evidence entry or guided/system content.
enum RecommendationItem: Equatable, Sendable {
    case personal(RecommendableEntry)
    case guided(GuidedContentItem)

    var id: UUID {
        switch self {
        case .personal(let entry):
            return entry.id
        case .guided(let content):
            return content.id
        }
    }

    var title: String {
        switch self {
        case .personal(let entry):
            return entry.title
        case .guided(let content):
            return content.title
        }
    }

    var isGuided: Bool {
        switch self {
        case .personal:
            return false
        case .guided:
            return true
        }
    }

    var isGrounding: Bool {
        switch self {
        case .personal(let entry):
            return entry.entryType == .groundingTechnique
        case .guided(let content):
            return content.contentType == .groundingExercise
        }
    }
}

/// Snapshot of a personal entry used by the scoring engine (SwiftData-agnostic).
struct RecommendableEntry: Equatable, Sendable, Identifiable {
    let id: UUID
    let title: String
    let bodyText: String?
    let meaningPromptAnswer: String
    let entryType: EntryType
    let isFavorite: Bool
    let isArchived: Bool
    let isSensitive: Bool
    let excludeFromCheckIns: Bool
    let pendingDeletion: Bool
    let localImageFileName: String?
    let remoteMediaPath: String?
    let meaningfulDate: Date?
    let emotionTags: [Emotion]
    let supportNeedTags: [SupportNeed]
    let strengthTags: [Strength]
    let updatedAt: Date

    init(
        id: UUID,
        title: String,
        bodyText: String? = nil,
        meaningPromptAnswer: String,
        entryType: EntryType,
        isFavorite: Bool = false,
        isArchived: Bool = false,
        isSensitive: Bool = false,
        excludeFromCheckIns: Bool = false,
        pendingDeletion: Bool = false,
        localImageFileName: String? = nil,
        remoteMediaPath: String? = nil,
        meaningfulDate: Date? = nil,
        emotionTags: [Emotion] = [],
        supportNeedTags: [SupportNeed] = [],
        strengthTags: [Strength] = [],
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.bodyText = bodyText
        self.meaningPromptAnswer = meaningPromptAnswer
        self.entryType = entryType
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.isSensitive = isSensitive
        self.excludeFromCheckIns = excludeFromCheckIns
        self.pendingDeletion = pendingDeletion
        self.localImageFileName = localImageFileName
        self.remoteMediaPath = remoteMediaPath
        self.meaningfulDate = meaningfulDate
        self.emotionTags = emotionTags
        self.supportNeedTags = supportNeedTags
        self.strengthTags = strengthTags
        self.updatedAt = updatedAt
    }

    /// Builds a scoring snapshot from a SwiftData entry and its tags.
    init(entry: EvidenceEntry) {
        let tags = entry.tags
        self.id = entry.id
        self.title = entry.title
        self.bodyText = entry.bodyText
        self.meaningPromptAnswer = entry.meaningPromptAnswer
        self.entryType = entry.entryType
        self.isFavorite = entry.isFavorite
        self.isArchived = entry.isArchived
        self.isSensitive = entry.isSensitive
        self.excludeFromCheckIns = entry.excludeFromCheckIns
        self.pendingDeletion = entry.pendingDeletion
        self.localImageFileName = entry.localImageFileName
        self.remoteMediaPath = entry.remoteMediaPath
        self.meaningfulDate = entry.meaningfulDate
        self.emotionTags = tags.compactMap { tag in
            guard tag.tagType == .emotion else { return nil }
            return Emotion.allCases.first { $0.displayName.caseInsensitiveCompare(tag.name) == .orderedSame }
                ?? Emotion(rawValue: tag.name)
        }
        self.supportNeedTags = tags.compactMap { tag in
            guard tag.tagType == .supportNeed else { return nil }
            return SupportNeed.allCases.first { $0.displayName.caseInsensitiveCompare(tag.name) == .orderedSame }
                ?? SupportNeed(rawValue: tag.name)
        }
        self.strengthTags = tags.compactMap { tag in
            guard tag.tagType == .strength else { return nil }
            return Strength.allCases.first { $0.displayName.caseInsensitiveCompare(tag.name) == .orderedSame }
                ?? Strength(rawValue: tag.name)
        }
        self.updatedAt = entry.updatedAt
    }
}

/// Prior feedback used for scoring adjustments.
struct FeedbackSnapshot: Equatable, Sendable {
    let evidenceEntryID: UUID?
    let guidedContentID: UUID?
    let response: FeedbackResponse
    let emotionAtTime: Emotion?
    let supportNeedAtTime: SupportNeed?
    let createdAt: Date
}

/// Recently shown item within the current or recent sessions.
struct RecentlyShownItem: Equatable, Sendable {
    let entryID: UUID?
    let guidedContentID: UUID?
    let shownAt: Date
}

/// Inputs for a single recommendation selection.
struct RecommendationInput: Sendable {
    var emotion: Emotion
    var supportNeed: SupportNeed
    var intensity: Int?
    var entries: [RecommendableEntry]
    var guidedContent: [GuidedContentItem]
    var feedback: [FeedbackSnapshot]
    var recentlyShown: [RecentlyShownItem]
    var excludeEntryIDs: Set<UUID>
    var excludeGuidedIDs: Set<UUID>
    /// When true, skip emotionally charged personal content (e.g. after madeThingsHarder).
    var preferNeutralGrounding: Bool

    init(
        emotion: Emotion,
        supportNeed: SupportNeed,
        intensity: Int? = nil,
        entries: [RecommendableEntry] = [],
        guidedContent: [GuidedContentItem] = [],
        feedback: [FeedbackSnapshot] = [],
        recentlyShown: [RecentlyShownItem] = [],
        excludeEntryIDs: Set<UUID> = [],
        excludeGuidedIDs: Set<UUID> = [],
        preferNeutralGrounding: Bool = false
    ) {
        self.emotion = emotion
        self.supportNeed = supportNeed
        self.intensity = intensity
        self.entries = entries
        self.guidedContent = guidedContent
        self.feedback = feedback
        self.recentlyShown = recentlyShown
        self.excludeEntryIDs = excludeEntryIDs
        self.excludeGuidedIDs = excludeGuidedIDs
        self.preferNeutralGrounding = preferNeutralGrounding
    }
}

// MARK: - Engine

/// Deterministic, testable recommendation scoring with a small randomized tie-break.
struct RecommendationEngine: Sendable {
    var dateProvider: any DateProviding
    /// Injected RNG for reproducible tie-breaks in tests.
    var randomNumberGenerator: any RandomNumberGenerator & Sendable

    /// Scores within this delta of the top score compete in the tie-break pool.
    var tieBreakScoreDelta: Double = 1.5

    /// Yearly meaningful-date window (± days).
    var meaningfulDateWindowDays: Int = 14

    init(
        dateProvider: any DateProviding = SystemDateProvider(),
        randomNumberGenerator: any RandomNumberGenerator & Sendable = SystemRandomNumberGenerator()
    ) {
        self.dateProvider = dateProvider
        self.randomNumberGenerator = randomNumberGenerator
    }

    /// Selects the best recommendation using the product scoring rules and fallback chain.
    mutating func recommend(from input: RecommendationInput) -> RecommendationResult? {
        let now = dateProvider.now

        if input.preferNeutralGrounding {
            if let grounding = selectGrounding(from: input, now: now) {
                return grounding
            }
        }

        // 1. Matching personal evidence
        let personalExact = scorePersonalEntries(input: input, now: now, requireEmotionMatch: true)
        if let best = pickBest(from: personalExact) {
            return best
        }

        // 2. Broader personal evidence matching support need
        let personalNeed = scorePersonalEntries(input: input, now: now, requireEmotionMatch: false)
        if let best = pickBest(from: personalNeed) {
            return best
        }

        // 3. Guided content matching the context
        let guided = scoreGuidedContent(input: input, now: now, groundingOnly: false)
        if let best = pickBest(from: guided) {
            return best
        }

        // 4. Neutral grounding exercise
        return selectGrounding(from: input, now: now)
    }

    /// Non-mutating convenience that copies the engine for the call.
    func recommendCopyingRNG(from input: RecommendationInput) -> RecommendationResult? {
        var copy = self
        return copy.recommend(from: input)
    }
}

// MARK: - Scoring

private extension RecommendationEngine {
    struct ScoredCandidate: Equatable {
        var result: RecommendationResult
    }

    func scorePersonalEntries(
        input: RecommendationInput,
        now: Date,
        requireEmotionMatch: Bool
    ) -> [ScoredCandidate] {
        var scored: [ScoredCandidate] = []

        for entry in input.entries {
            guard isEligiblePersonal(entry, excludeIDs: input.excludeEntryIDs) else { continue }

            // Never recommend untagged random images / media without meaning tags.
            let hasRelevantTags = !entry.emotionTags.isEmpty || !entry.supportNeedTags.isEmpty
            guard hasRelevantTags else { continue }
            guard !entry.meaningPromptAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            let matchesEmotion = entry.emotionTags.contains(input.emotion)
            let matchesNeed = entry.supportNeedTags.contains(input.supportNeed)

            if requireEmotionMatch && !matchesEmotion {
                continue
            }
            if !requireEmotionMatch && !matchesNeed {
                continue
            }

            var score: Double = 0
            var reasons: [String] = []
            var matched: [String] = []

            if matchesNeed {
                score += 6
                matched.append(input.supportNeed.displayName)
                reasons.append("tagged for \(input.supportNeed.displayName.lowercased())")
            }
            if matchesEmotion {
                score += 5
                matched.append(input.emotion.displayName)
                reasons.append("tagged for \(input.emotion.displayName.lowercased())")
            }

            let entryFeedback = input.feedback.filter { $0.evidenceEntryID == entry.id }

            if entryFeedback.contains(where: {
                $0.response == .helped && $0.emotionAtTime == input.emotion
            }) {
                score += 3
                reasons.append("previously helped when you felt \(input.emotion.displayName.lowercased())")
            }

            if entryFeedback.contains(where: {
                $0.response == .helped && $0.supportNeedAtTime == input.supportNeed
            }) {
                score += 3
                reasons.append("previously helped for \(input.supportNeed.displayName.lowercased())")
            }

            if entry.isFavorite {
                score += 2
                reasons.append("one of your favorites")
            }

            if let meaningful = entry.meaningfulDate,
               isWithinYearlyWindow(meaningful, now: now, days: meaningfulDateWindowDays) {
                score += 2
                reasons.append("important around this time of year")
            }

            if !entry.strengthTags.isEmpty {
                score += 1
                if let first = entry.strengthTags.first {
                    matched.append(first.displayName)
                }
            }

            if wasShownRecently(entryID: entry.id, guidedID: nil, in: input.recentlyShown, now: now, days: 7) {
                score -= 4
            }

            if entryFeedback.contains(where: {
                $0.response == .notRelevant
                    && $0.emotionAtTime == input.emotion
                    && $0.supportNeedAtTime == input.supportNeed
            }) {
                score -= 7
            }

            if entryFeedback.contains(where: {
                $0.response == .doNotUseForThisFeeling && $0.emotionAtTime == input.emotion
            }) {
                score -= 10
            }

            if entryFeedback.contains(where: {
                $0.response == .madeThingsHarder
                    && ($0.emotionAtTime == input.emotion || $0.supportNeedAtTime == input.supportNeed)
            }) {
                score -= 20
            }

            // Hard floor: heavily negative items drop out of matching personal tier.
            if score < -5 {
                continue
            }

            let reason = humanReadableReason(reasons: reasons, isGuided: false, entry: entry)
            scored.append(
                ScoredCandidate(
                    result: RecommendationResult(
                        item: .personal(entry),
                        score: score,
                        selectionReason: reason,
                        matchedTags: Array(Set(matched)).sorted(),
                        isGuided: false
                    )
                )
            )
        }

        return scored
    }

    func scoreGuidedContent(
        input: RecommendationInput,
        now: Date,
        groundingOnly: Bool
    ) -> [ScoredCandidate] {
        var scored: [ScoredCandidate] = []

        for content in input.guidedContent where content.isActive {
            if input.excludeGuidedIDs.contains(content.id) { continue }
            if groundingOnly && content.contentType != .groundingExercise { continue }
            if !groundingOnly && content.contentType == .groundingExercise {
                // Prefer contextual guided first; grounding is the explicit fallback.
            }

            let matchesEmotion = content.supportedEmotions.contains(input.emotion)
            let matchesNeed = content.supportedNeeds.contains(input.supportNeed)

            if groundingOnly {
                // All grounding exercises eligible.
            } else if !(matchesEmotion || matchesNeed) {
                continue
            }

            var score: Double = groundingOnly ? 1 : 0
            var reasons: [String] = []
            var matched: [String] = []

            if matchesNeed {
                score += 6
                matched.append(input.supportNeed.displayName)
                reasons.append("support for \(input.supportNeed.displayName.lowercased())")
            }
            if matchesEmotion {
                score += 5
                matched.append(input.emotion.displayName)
                reasons.append("support when feeling \(input.emotion.displayName.lowercased())")
            }

            let contentFeedback = input.feedback.filter { $0.guidedContentID == content.id }

            if contentFeedback.contains(where: {
                $0.response == .helped && $0.emotionAtTime == input.emotion
            }) {
                score += 3
            }
            if contentFeedback.contains(where: {
                $0.response == .helped && $0.supportNeedAtTime == input.supportNeed
            }) {
                score += 3
            }

            if wasShownRecently(entryID: nil, guidedID: content.id, in: input.recentlyShown, now: now, days: 7) {
                score -= 4
            }

            if contentFeedback.contains(where: {
                $0.response == .notRelevant
                    && $0.emotionAtTime == input.emotion
                    && $0.supportNeedAtTime == input.supportNeed
            }) {
                score -= 7
            }

            if contentFeedback.contains(where: {
                $0.response == .doNotUseForThisFeeling && $0.emotionAtTime == input.emotion
            }) {
                score -= 10
            }

            if contentFeedback.contains(where: { $0.response == .madeThingsHarder }) {
                score -= 20
            }

            if score < -5 { continue }

            let reason: String
            if groundingOnly || content.contentType == .groundingExercise {
                reason = "A calm grounding exercise you can try right now."
            } else {
                reason = humanReadableReason(reasons: reasons, isGuided: true, entry: nil)
            }

            scored.append(
                ScoredCandidate(
                    result: RecommendationResult(
                        item: .guided(content),
                        score: score,
                        selectionReason: reason,
                        matchedTags: Array(Set(matched)).sorted(),
                        isGuided: true
                    )
                )
            )
        }

        return scored
    }

    func selectGrounding(from input: RecommendationInput, now: Date) -> RecommendationResult? {
        let guidedGrounding = scoreGuidedContent(input: input, now: now, groundingOnly: true)
        if let best = pickBest(from: guidedGrounding) {
            return best
        }

        // Personal grounding technique entries as last resort.
        let personalGrounding = input.entries.filter {
            $0.entryType == .groundingTechnique && isEligiblePersonal($0, excludeIDs: input.excludeEntryIDs)
        }
        guard let entry = personalGrounding.first else { return nil }
        return RecommendationResult(
            item: .personal(entry),
            score: 0,
            selectionReason: "A grounding technique from your collection.",
            matchedTags: [],
            isGuided: false
        )
    }

    mutating func pickBest(from candidates: [ScoredCandidate]) -> RecommendationResult? {
        guard !candidates.isEmpty else { return nil }
        let sorted = candidates.sorted { $0.result.score > $1.result.score }
        guard let top = sorted.first else { return nil }
        let threshold = top.result.score - tieBreakScoreDelta
        let pool = sorted.filter { $0.result.score >= threshold }
        if pool.count == 1 {
            return top.result
        }
        let index = Int.random(in: 0..<pool.count, using: &randomNumberGenerator)
        return pool[index].result
    }
}

// MARK: - Eligibility & helpers

private extension RecommendationEngine {
    func isEligiblePersonal(_ entry: RecommendableEntry, excludeIDs: Set<UUID>) -> Bool {
        if excludeIDs.contains(entry.id) { return false }
        if entry.isArchived { return false }
        if entry.pendingDeletion { return false }
        if entry.excludeFromCheckIns { return false }

        // Image entries without media are invalid for recommendation.
        if entry.entryType == .image {
            let hasLocal = !(entry.localImageFileName ?? "").isEmpty
            let hasRemote = !(entry.remoteMediaPath ?? "").isEmpty
            if !hasLocal && !hasRemote {
                return false
            }
        }
        return true
    }

    func wasShownRecently(
        entryID: UUID?,
        guidedID: UUID?,
        in recent: [RecentlyShownItem],
        now: Date,
        days: Int
    ) -> Bool {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        return recent.contains { item in
            guard item.shownAt >= cutoff else { return false }
            if let entryID, item.entryID == entryID { return true }
            if let guidedID, item.guidedContentID == guidedID { return true }
            return false
        }
    }

    func isWithinYearlyWindow(_ meaningful: Date, now: Date, days: Int) -> Bool {
        let calendar = Calendar.current
        let meaningfulParts = calendar.dateComponents([.month, .day], from: meaningful)
        let nowParts = calendar.dateComponents([.year, .month, .day], from: now)
        guard
            let month = meaningfulParts.month,
            let day = meaningfulParts.day,
            let year = nowParts.year,
            let thisYear = calendar.date(from: DateComponents(year: year, month: month, day: day))
        else {
            return false
        }

        let previousYear = calendar.date(byAdding: .year, value: -1, to: thisYear) ?? thisYear
        let nextYear = calendar.date(byAdding: .year, value: 1, to: thisYear) ?? thisYear

        let window = TimeInterval(days * 24 * 60 * 60)
        let candidates = [previousYear, thisYear, nextYear]
        return candidates.contains { abs($0.timeIntervalSince(now)) <= window }
    }

    func humanReadableReason(reasons: [String], isGuided: Bool, entry: RecommendableEntry?) -> String {
        if let first = reasons.first {
            if first.hasPrefix("previously helped") {
                return "You previously said this helped when you felt related feelings."
            }
            if first.contains("time of year") {
                return "You marked this as important around this time of year."
            }
            if first.contains("favorites") {
                return "This is one of your saved favorites."
            }
            if isGuided {
                return "A guided reminder matched to what you shared."
            }
            if let entry, !entry.supportNeedTags.isEmpty || !entry.emotionTags.isEmpty {
                let emotionPart = entry.emotionTags.first.map { $0.displayName.lowercased() }
                let needPart = entry.supportNeedTags.first.map { $0.displayName.lowercased() }
                if let emotionPart, let needPart {
                    return "Shown because you tagged this for \(emotionPart) and \(needPart)."
                }
                if let needPart {
                    return "Shown because you tagged this for \(needPart)."
                }
                if let emotionPart {
                    return "Shown because you tagged this for when you feel \(emotionPart)."
                }
            }
            return "This is one of your saved reminders about what matters to you."
        }
        if isGuided {
            return "A guided reminder that may help right now."
        }
        return "This is one of your saved reminders about capability."
    }
}

// MARK: - Seedable RNG for tests

/// Deterministic RNG for reproducible recommendation tests.
struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x4d595df4d0f33173 : seed
    }

    mutating func next() -> UInt64 {
        // xorshift64*
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 0x2545F4914F6CDD1D
    }
}

extension SystemRandomNumberGenerator: @unchecked Sendable {}
