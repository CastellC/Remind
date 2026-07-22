import Foundation

/// Field snapshot used by pure search matching (SwiftData-agnostic).
struct EvidenceSearchableFields: Equatable, Sendable {
    var title: String
    var bodyText: String?
    var meaningPromptAnswer: String
    var sourceName: String?
    var tagNames: [String]
    var categoryNames: [String]

    init(
        title: String,
        bodyText: String? = nil,
        meaningPromptAnswer: String = "",
        sourceName: String? = nil,
        tagNames: [String] = [],
        categoryNames: [String] = []
    ) {
        self.title = title
        self.bodyText = bodyText
        self.meaningPromptAnswer = meaningPromptAnswer
        self.sourceName = sourceName
        self.tagNames = tagNames
        self.categoryNames = categoryNames
    }

    init(entry: EvidenceEntry) {
        self.title = entry.title
        self.bodyText = entry.bodyText
        self.meaningPromptAnswer = entry.meaningPromptAnswer
        self.sourceName = entry.sourceName
        self.tagNames = entry.tags.map(\.name)
        self.categoryNames = entry.categories.map(\.name)
    }
}

/// Case-insensitive search across title, body, meaning, source, tags, and categories.
enum EvidenceSearchService {
    /// Returns `true` when `query` is empty/whitespace or matches any searchable field.
    static func matches(_ fields: EvidenceSearchableFields, query: String) -> Bool {
        let needle = normalizedQuery(query)
        guard !needle.isEmpty else { return true }

        let haystacks: [String] = [
            fields.title,
            fields.bodyText ?? "",
            fields.meaningPromptAnswer,
            fields.sourceName ?? "",
            fields.tagNames.joined(separator: " "),
            fields.categoryNames.joined(separator: " ")
        ]

        return haystacks
            .joined(separator: " ")
            .lowercased()
            .contains(needle)
    }

    /// Filters items whose searchable fields match `query`.
    static func filter<T>(
        _ items: [T],
        query: String,
        fields: (T) -> EvidenceSearchableFields
    ) -> [T] {
        let needle = normalizedQuery(query)
        guard !needle.isEmpty else { return items }
        return items.filter { matches(fields($0), query: needle) }
    }

    /// Filters entry field snapshots by query.
    static func filterEntries(
        _ entries: [EvidenceSearchableFields],
        query: String
    ) -> [EvidenceSearchableFields] {
        filter(entries, query: query, fields: { $0 })
    }

    static func normalizedQuery(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
