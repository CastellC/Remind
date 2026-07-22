import Foundation
import SwiftData

/// Bundled guided content item — primary representation loaded from JSON.
struct GuidedContentItem: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var body: String
    var contentType: GuidedContentType
    var supportedEmotions: [Emotion]
    var supportedNeeds: [SupportNeed]
    var isActive: Bool
    var version: Int

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case contentType
        case supportedEmotions
        case supportedNeeds
        case isActive
        case version
    }

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        contentType: GuidedContentType,
        supportedEmotions: [Emotion] = [],
        supportedNeeds: [SupportNeed] = [],
        isActive: Bool = true,
        version: Int = 1
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.contentType = contentType
        self.supportedEmotions = supportedEmotions
        self.supportedNeeds = supportedNeeds
        self.isActive = isActive
        self.version = version
    }

    var displayName: String { title }

    var systemContentLabel: String { contentType.systemContentLabel }

    func supports(emotion: Emotion) -> Bool {
        supportedEmotions.isEmpty || supportedEmotions.contains(emotion)
    }

    func supports(need: SupportNeed) -> Bool {
        supportedNeeds.isEmpty || supportedNeeds.contains(need)
    }

    /// Loads guided items from a bundled JSON file.
    static func load(from bundle: Bundle = .main, resourceName: String = "GuidedContent") throws -> [GuidedContentItem] {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw GuidedContentLoadError.resourceNotFound(resourceName)
        }
        let data = try Data(contentsOf: url)
        return try decodeList(from: data)
    }

    static func decodeList(from data: Data) throws -> [GuidedContentItem] {
        let decoder = JSONDecoder()
        if let list = try? decoder.decode([GuidedContentItem].self, from: data) {
            return list
        }
        let wrapped = try decoder.decode(GuidedContentEnvelope.self, from: data)
        return wrapped.items
    }

    private struct GuidedContentEnvelope: Codable {
        var items: [GuidedContentItem]
    }
}

enum GuidedContentLoadError: Error, LocalizedError {
    case resourceNotFound(String)

    var errorDescription: String? {
        switch self {
        case .resourceNotFound(let name):
            return "Guided content resource “\(name).json” was not found in the bundle."
        }
    }
}

/// Optional SwiftData path for caching or customizing guided content locally.
@Model
final class GuidedContentRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var body: String
    var contentTypeRaw: String
    var supportedEmotionsData: Data
    var supportedNeedsData: Data
    var isActive: Bool
    var version: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        contentType: GuidedContentType,
        supportedEmotions: [Emotion] = [],
        supportedNeeds: [SupportNeed] = [],
        isActive: Bool = true,
        version: Int = 1,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.contentTypeRaw = contentType.rawValue
        self.supportedEmotionsData = CodableStorage.encodeRawRepresentableArray(supportedEmotions)
        self.supportedNeedsData = CodableStorage.encodeRawRepresentableArray(supportedNeeds)
        self.isActive = isActive
        self.version = version
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    convenience init(item: GuidedContentItem) {
        self.init(
            id: item.id,
            title: item.title,
            body: item.body,
            contentType: item.contentType,
            supportedEmotions: item.supportedEmotions,
            supportedNeeds: item.supportedNeeds,
            isActive: item.isActive,
            version: item.version
        )
    }

    var contentType: GuidedContentType {
        get { GuidedContentType(rawValue: contentTypeRaw) ?? .groundedAffirmation }
        set { contentTypeRaw = newValue.rawValue }
    }

    var supportedEmotions: [Emotion] {
        get { CodableStorage.decodeRawRepresentableArray(Emotion.self, from: supportedEmotionsData) }
        set { supportedEmotionsData = CodableStorage.encodeRawRepresentableArray(newValue) }
    }

    var supportedNeeds: [SupportNeed] {
        get { CodableStorage.decodeRawRepresentableArray(SupportNeed.self, from: supportedNeedsData) }
        set { supportedNeedsData = CodableStorage.encodeRawRepresentableArray(newValue) }
    }

    func asItem() -> GuidedContentItem {
        GuidedContentItem(
            id: id,
            title: title,
            body: body,
            contentType: contentType,
            supportedEmotions: supportedEmotions,
            supportedNeeds: supportedNeeds,
            isActive: isActive,
            version: version
        )
    }

    func touch(_ date: Date = .now) {
        updatedAt = date
    }
}
