import XCTest
@testable import Evidence

final class RecommendationEngineTests: XCTestCase {
    private var now: Date!
    private var engine: RecommendationEngine!

    override func setUp() {
        super.setUp()
        now = Date(timeIntervalSince1970: 1_720_000_000)
        engine = RecommendationEngine(
            dateProvider: FixedDateProvider(now: now),
            randomNumberGenerator: SeededGenerator(seed: 42)
        )
    }

    // MARK: - Fixtures

    private func entry(
        id: UUID = UUID(),
        title: String = "Entry",
        meaning: String = "Someone believed in me",
        entryType: EntryType = .text,
        isFavorite: Bool = false,
        isArchived: Bool = false,
        excludeFromCheckIns: Bool = false,
        pendingDeletion: Bool = false,
        localImageFileName: String? = nil,
        remoteMediaPath: String? = nil,
        meaningfulDate: Date? = nil,
        emotions: [Emotion] = [.anxious],
        needs: [SupportNeed] = [.reassurance],
        strengths: [Strength] = [],
        updatedAt: Date? = nil
    ) -> RecommendableEntry {
        RecommendableEntry(
            id: id,
            title: title,
            bodyText: nil,
            meaningPromptAnswer: meaning,
            entryType: entryType,
            isFavorite: isFavorite,
            isArchived: isArchived,
            excludeFromCheckIns: excludeFromCheckIns,
            pendingDeletion: pendingDeletion,
            localImageFileName: localImageFileName,
            remoteMediaPath: remoteMediaPath,
            meaningfulDate: meaningfulDate,
            emotionTags: emotions,
            supportNeedTags: needs,
            strengthTags: strengths,
            updatedAt: updatedAt ?? now
        )
    }

    private func guided(
        id: UUID = UUID(),
        title: String = "Guided",
        contentType: GuidedContentType = .groundedAffirmation,
        emotions: [Emotion] = [.anxious],
        needs: [SupportNeed] = [.reassurance],
        isActive: Bool = true
    ) -> GuidedContentItem {
        GuidedContentItem(
            id: id,
            title: title,
            body: "Body",
            contentType: contentType,
            supportedEmotions: emotions,
            supportedNeeds: needs,
            isActive: isActive
        )
    }

    private func input(
        emotion: Emotion = .anxious,
        need: SupportNeed = .reassurance,
        entries: [RecommendableEntry] = [],
        guidedContent: [GuidedContentItem] = [],
        feedback: [FeedbackSnapshot] = [],
        recentlyShown: [RecentlyShownItem] = [],
        preferNeutralGrounding: Bool = false
    ) -> RecommendationInput {
        RecommendationInput(
            emotion: emotion,
            supportNeed: need,
            entries: entries,
            guidedContent: guidedContent,
            feedback: feedback,
            recentlyShown: recentlyShown,
            preferNeutralGrounding: preferNeutralGrounding
        )
    }

    // MARK: - Emotion & support need match

    func testEmotionMatchPreferredOverNeedOnly() {
        let emotionMatch = entry(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "Emotion match",
            emotions: [.anxious],
            needs: [.perspective]
        )
        let needOnly = entry(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            title: "Need only",
            emotions: [.down],
            needs: [.reassurance]
        )

        let result = engine.recommendCopyingRNG(
            from: input(entries: [needOnly, emotionMatch])
        )

        XCTAssertEqual(result?.item.id, emotionMatch.id)
        XCTAssertFalse(result?.isGuided ?? true)
        XCTAssertGreaterThan(result?.score ?? 0, 0)
    }

    func testSupportNeedMatchUsedWhenNoEmotionMatch() {
        let needMatch = entry(
            title: "Need match",
            emotions: [.lonely],
            needs: [.reassurance]
        )
        let unrelated = entry(
            title: "Unrelated",
            emotions: [.angry],
            needs: [.grounding]
        )

        let result = engine.recommendCopyingRNG(
            from: input(entries: [unrelated, needMatch])
        )

        XCTAssertEqual(result?.item.id, needMatch.id)
    }

    // MARK: - Exclusions

    func testExcludesArchivedEntries() {
        let archived = entry(title: "Archived", isArchived: true)
        let active = entry(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            title: "Active",
            emotions: [.anxious],
            needs: [.reassurance]
        )

        let result = engine.recommendCopyingRNG(from: input(entries: [archived, active]))
        XCTAssertEqual(result?.item.id, active.id)
    }

    func testExcludesPendingDeletionEntries() {
        let pending = entry(title: "Pending", pendingDeletion: true)
        let active = entry(title: "Active")

        let result = engine.recommendCopyingRNG(from: input(entries: [pending, active]))
        XCTAssertEqual(result?.item.id, active.id)
    }

    func testExcludesExcludeFromCheckInsEntries() {
        let excluded = entry(title: "Excluded", excludeFromCheckIns: true)
        let active = entry(title: "Active")

        let result = engine.recommendCopyingRNG(from: input(entries: [excluded, active]))
        XCTAssertEqual(result?.item.id, active.id)
    }

    // MARK: - Recent penalty

    func testRecentPenaltyLowersScoreRelativeToUnshown() {
        let recentID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let freshID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        let recent = entry(id: recentID, title: "Recent", isFavorite: true)
        let fresh = entry(id: freshID, title: "Fresh", isFavorite: true)

        let recentlyShown = [
            RecentlyShownItem(entryID: recentID, guidedContentID: nil, shownAt: now.addingTimeInterval(-3600))
        ]

        let result = engine.recommendCopyingRNG(
            from: input(entries: [recent, fresh], recentlyShown: recentlyShown)
        )

        XCTAssertEqual(result?.item.id, freshID)
    }

    // MARK: - Feedback weights

    func testHelpfulFeedbackIncreasesScore() {
        let helpedID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        let otherID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
        let helped = entry(id: helpedID, title: "Helped before")
        let other = entry(id: otherID, title: "Other")

        let feedback = [
            FeedbackSnapshot(
                evidenceEntryID: helpedID,
                guidedContentID: nil,
                response: .helped,
                emotionAtTime: .anxious,
                supportNeedAtTime: .reassurance,
                createdAt: now.addingTimeInterval(-86_400)
            )
        ]

        let result = engine.recommendCopyingRNG(
            from: input(entries: [other, helped], feedback: feedback)
        )

        XCTAssertEqual(result?.item.id, helpedID)
        XCTAssertGreaterThanOrEqual(result?.score ?? 0, 11)
    }

    func testMadeThingsHarderDropsEntryFromPersonalTier() {
        let hardID = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
        let hard = entry(id: hardID, title: "Harder")
        let grounding = guided(
            title: "Ground",
            contentType: .groundingExercise,
            emotions: [],
            needs: []
        )

        let feedback = [
            FeedbackSnapshot(
                evidenceEntryID: hardID,
                guidedContentID: nil,
                response: .madeThingsHarder,
                emotionAtTime: .anxious,
                supportNeedAtTime: .reassurance,
                createdAt: now
            )
        ]

        let result = engine.recommendCopyingRNG(
            from: input(entries: [hard], guidedContent: [grounding], feedback: feedback)
        )

        XCTAssertNotEqual(result?.item.id, hardID)
        XCTAssertTrue(result?.isGuided ?? false)
    }

    func testPreferNeutralGroundingSelectsGroundingFirst() {
        let personal = entry(title: "Personal match")
        let grounding = guided(
            title: "Breathe",
            contentType: .groundingExercise,
            emotions: [],
            needs: []
        )

        let result = engine.recommendCopyingRNG(
            from: input(
                entries: [personal],
                guidedContent: [grounding],
                preferNeutralGrounding: true
            )
        )

        XCTAssertEqual(result?.item.id, grounding.id)
        XCTAssertTrue(result?.isGuided ?? false)
    }

    // MARK: - Guided fallback

    func testGuidedFallbackWhenNoPersonalMatches() {
        let unrelated = entry(
            title: "Unrelated",
            emotions: [.angry],
            needs: [.perspective]
        )
        let guidedItem = guided(
            title: "Guided match",
            emotions: [.anxious],
            needs: [.reassurance]
        )

        let result = engine.recommendCopyingRNG(
            from: input(entries: [unrelated], guidedContent: [guidedItem])
        )

        XCTAssertEqual(result?.item.id, guidedItem.id)
        XCTAssertTrue(result?.isGuided ?? false)
    }

    func testGroundingFallbackWhenNothingMatches() {
        let grounding = guided(
            title: "5-4-3-2-1",
            contentType: .groundingExercise,
            emotions: [.overwhelmed],
            needs: [.grounding]
        )

        let result = engine.recommendCopyingRNG(
            from: input(
                emotion: .numb,
                need: .quietReflection,
                guidedContent: [grounding]
            )
        )

        XCTAssertEqual(result?.item.id, grounding.id)
        XCTAssertTrue(result?.item.isGrounding ?? false)
    }

    // MARK: - Meaningful date & favorites

    func testMeaningfulDateBoostWithinWindow() {
        let calendar = Calendar.current
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        guard
            let year = parts.year,
            let month = parts.month,
            let day = parts.day,
            let meaningful = calendar.date(from: DateComponents(year: year - 1, month: month, day: day))
        else {
            return XCTFail("Could not build meaningful date")
        }

        let datedID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
        let plainID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let dated = entry(id: datedID, title: "Dated", meaningfulDate: meaningful)
        let plain = entry(id: plainID, title: "Plain")

        let result = engine.recommendCopyingRNG(from: input(entries: [plain, dated]))
        XCTAssertEqual(result?.item.id, datedID)
        XCTAssertTrue(
            result?.selectionReason.lowercased().contains("time of year") == true
                || (result?.score ?? 0) >= 13
        )
    }

    func testFavoriteBoost() {
        let favoriteID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let favorite = entry(id: favoriteID, title: "Favorite", isFavorite: true)
        let plain = entry(title: "Plain", isFavorite: false)

        let result = engine.recommendCopyingRNG(from: input(entries: [plain, favorite]))
        XCTAssertEqual(result?.item.id, favoriteID)
    }

    // MARK: - Untagged images

    func testNeverRecommendsUntaggedImageWithoutTags() {
        let untaggedImage = entry(
            title: "Random photo",
            meaning: "A nice day",
            entryType: .image,
            localImageFileName: "abc-display.jpg",
            emotions: [],
            needs: []
        )
        let guidedItem = guided(
            title: "Fallback guided",
            contentType: .groundingExercise,
            emotions: [],
            needs: []
        )

        let result = engine.recommendCopyingRNG(
            from: input(entries: [untaggedImage], guidedContent: [guidedItem])
        )

        XCTAssertNotEqual(result?.item.id, untaggedImage.id)
        XCTAssertEqual(result?.item.id, guidedItem.id)
    }

    func testImageWithoutMediaIsIneligible() {
        let noMedia = entry(
            title: "Broken image",
            entryType: .image,
            localImageFileName: nil,
            remoteMediaPath: nil,
            emotions: [.anxious],
            needs: [.reassurance]
        )
        let text = entry(title: "Text")

        let result = engine.recommendCopyingRNG(from: input(entries: [noMedia, text]))
        XCTAssertEqual(result?.item.id, text.id)
    }

    func testEmptyMeaningAnswerIsSkipped() {
        let emptyMeaning = entry(
            title: "No meaning",
            meaning: "   ",
            emotions: [.anxious],
            needs: [.reassurance]
        )
        let valid = entry(title: "Valid")

        let result = engine.recommendCopyingRNG(from: input(entries: [emptyMeaning, valid]))
        XCTAssertEqual(result?.item.id, valid.id)
    }
}
