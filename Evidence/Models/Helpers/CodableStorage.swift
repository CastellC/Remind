import Foundation

/// Helpers for persisting arrays and Codable values as JSON `Data` or CSV `String`
/// inside SwiftData properties.
enum CodableStorage {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func encodeJSON<T: Encodable>(_ value: T) -> Data {
        (try? encoder.encode(value)) ?? Data()
    }

    static func decodeJSON<T: Decodable>(_ type: T.Type, from data: Data?, default defaultValue: T) -> T {
        guard let data, !data.isEmpty else { return defaultValue }
        return (try? decoder.decode(T.self, from: data)) ?? defaultValue
    }

    static func encodeStringArray(_ values: [String]) -> Data {
        encodeJSON(values)
    }

    static func decodeStringArray(from data: Data?) -> [String] {
        decodeJSON([String].self, from: data, default: [])
    }

    static func encodeUUIDArray(_ values: [UUID]) -> Data {
        encodeJSON(values.map(\.uuidString))
    }

    static func decodeUUIDArray(from data: Data?) -> [UUID] {
        let strings = decodeStringArray(from: data)
        return strings.compactMap(UUID.init(uuidString:))
    }

    static func encodeIntArray(_ values: [Int]) -> Data {
        encodeJSON(values)
    }

    static func decodeIntArray(from data: Data?) -> [Int] {
        decodeJSON([Int].self, from: data, default: [])
    }

    static func encodeRawRepresentableArray<T: RawRepresentable>(_ values: [T]) -> Data where T.RawValue == String {
        encodeJSON(values.map(\.rawValue))
    }

    static func decodeRawRepresentableArray<T: RawRepresentable>(
        _ type: T.Type,
        from data: Data?
    ) -> [T] where T.RawValue == String {
        decodeStringArray(from: data).compactMap(T.init(rawValue:))
    }

    /// Comma-separated fallback for simple string lists.
    static func encodeCSV(_ values: [String]) -> String {
        values
            .map { $0.replacingOccurrences(of: ",", with: "‚") }
            .joined(separator: ",")
    }

    static func decodeCSV(_ string: String?) -> [String] {
        guard let string, !string.isEmpty else { return [] }
        return string
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { String($0).replacingOccurrences(of: "‚", with: ",") }
    }
}
