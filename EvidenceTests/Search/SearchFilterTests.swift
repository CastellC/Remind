import XCTest
import SwiftData
@testable import Evidence

final class SearchFilterTests: XCTestCase {
    private func fields(
        title: String = "Title",
        body: String? = nil,
        meaning: String = "Meaning",
        source: String? = nil,
        tags: [String] = [],
        categories: [String] = []
    ) -> EvidenceSearchableFields {
        EvidenceSearchableFields(
            title: title,
            bodyText: body,
            meaningPromptAnswer: meaning,
            sourceName: source,
            tagNames: tags,
            categoryNames: categories
        )
    }

    func testEmptyQueryMatchesEverything() {
        let item = fields(title: "Hello")
        XCTAssertTrue(EvidenceSearchService.matches(item, query: ""))
        XCTAssertTrue(EvidenceSearchService.matches(item, query: "   "))
    }

    func testCaseInsensitiveTitleMatch() {
        let item = fields(title: "Kind Words From Alex")
        XCTAssertTrue(EvidenceSearchService.matches(item, query: "kind words"))
        XCTAssertTrue(EvidenceSearchService.matches(item, query: "ALEX"))
    }

    func testSearchesBodyText() {
        let item = fields(title: "Note", body: "You handled that with care")
        XCTAssertTrue(EvidenceSearchService.matches(item, query: "handled"))
        XCTAssertFalse(EvidenceSearchService.matches(item, query: "missing"))
    }

    func testSearchesMeaningPromptAnswer() {
        let item = fields(meaning: "Someone believed in me")
        XCTAssertTrue(EvidenceSearchService.matches(item, query: "believed"))
    }

    func testSearchesSourceName() {
        let item = fields(source: "Jordan")
        XCTAssertTrue(EvidenceSearchService.matches(item, query: "jordan"))
    }

    func testSearchesTags() {
        let item = fields(tags: ["Anxious", "Reassurance"])
        XCTAssertTrue(EvidenceSearchService.matches(item, query: "anxious"))
        XCTAssertTrue(EvidenceSearchService.matches(item, query: "reassurance"))
    }

    func testSearchesCategories() {
        let item = fields(categories: ["Support", "Work"])
        XCTAssertTrue(EvidenceSearchService.matches(item, query: "support"))
    }

    func testFilterEntriesReturnsOnlyMatches() {
        let entries = [
            fields(title: "Morning walk", tags: ["Capable"]),
            fields(title: "Hard day", body: "Felt lonely", tags: ["Lonely"]),
            fields(title: "Note", meaning: "Growth", source: "Sam")
        ]

        let byTitle = EvidenceSearchService.filterEntries(entries, query: "morning")
        XCTAssertEqual(byTitle.count, 1)
        XCTAssertEqual(byTitle.first?.title, "Morning walk")

        let byTag = EvidenceSearchService.filterEntries(entries, query: "lonely")
        XCTAssertEqual(byTag.count, 1)

        let bySource = EvidenceSearchService.filterEntries(entries, query: "sam")
        XCTAssertEqual(bySource.count, 1)
    }

    @MainActor
    func testCollectionViewModelUsesSearchService() throws {
        let container = try ModelContainer.evidence(inMemory: true)
        let context = ModelContext(container)

        let matching = EvidenceEntry(
            title: "Blue notebook",
            bodyText: "A gift",
            sourceName: "Alex",
            meaningPromptAnswer: "Someone believed in me"
        )
        let other = EvidenceEntry(
            title: "Unrelated",
            bodyText: "Other text",
            meaningPromptAnswer: "Evidence of growth"
        )
        context.insert(matching)
        context.insert(other)
        try context.save()

        let viewModel = CollectionViewModel()
        viewModel.searchText = "notebook"
        let filtered = viewModel.filtered(from: [matching, other], showArchivedOnly: false)
        XCTAssertEqual(filtered.map(\.id), [matching.id])

        viewModel.searchText = "alex"
        let bySource = viewModel.filtered(from: [matching, other], showArchivedOnly: false)
        XCTAssertEqual(bySource.map(\.id), [matching.id])
    }

    @MainActor
    func testCollectionViewModelHidesArchivedUnlessRequested() throws {
        let archived = EvidenceEntry(
            title: "Old",
            isArchived: true,
            meaningPromptAnswer: "Meaning"
        )
        let active = EvidenceEntry(
            title: "Current",
            meaningPromptAnswer: "Meaning"
        )

        let viewModel = CollectionViewModel()
        let activeOnly = viewModel.filtered(from: [archived, active], showArchivedOnly: false)
        XCTAssertEqual(activeOnly.map(\.id), [active.id])

        let archivedOnly = viewModel.filtered(from: [archived, active], showArchivedOnly: true)
        XCTAssertEqual(archivedOnly.map(\.id), [archived.id])
    }
}
