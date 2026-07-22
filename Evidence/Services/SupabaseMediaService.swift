import Foundation

#if canImport(Supabase)
import Supabase
#endif

/// Uploads and downloads private media in the `evidence-media` bucket.
protocol MediaServing: Sendable {
    func upload(
        data: Data,
        userID: UUID,
        entryID: UUID,
        assetID: UUID,
        fileExtension: String,
        contentType: String
    ) async throws -> String

    func download(path: String) async throws -> Data
    func delete(path: String) async throws
    func signedURL(path: String, expiresIn: TimeInterval) async throws -> URL
}

enum MediaServiceError: Error, LocalizedError, Sendable {
    case notConfigured
    case invalidPath
    case uploadFailed
    case downloadFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Media sync is not configured."
        case .invalidPath:
            return "The media path is invalid."
        case .uploadFailed:
            return "The image could not be uploaded."
        case .downloadFailed:
            return "The image could not be downloaded."
        case .deleteFailed:
            return "The remote image could not be deleted."
        }
    }
}

struct MediaPathBuilder {
    static let bucketName = "evidence-media"

    static func objectPath(userID: UUID, entryID: UUID, assetID: UUID, fileExtension: String) -> String {
        let ext = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        return "\(userID.uuidString.lowercased())/\(entryID.uuidString.lowercased())/\(assetID.uuidString.lowercased()).\(ext)"
    }

    static func isValid(_ path: String, userID: UUID) -> Bool {
        let prefix = userID.uuidString.lowercased() + "/"
        return path.lowercased().hasPrefix(prefix) && !path.contains("..")
    }
}

#if canImport(Supabase)
actor SupabaseMediaService: MediaServing {
    private let client: SupabaseClient
    private let bucket: String
    private let maxAttempts: Int
    private let signedURLLifetime: TimeInterval

    init(
        client: SupabaseClient,
        bucket: String = MediaPathBuilder.bucketName,
        maxAttempts: Int = 3,
        signedURLLifetime: TimeInterval = 120
    ) {
        self.client = client
        self.bucket = bucket
        self.maxAttempts = maxAttempts
        self.signedURLLifetime = signedURLLifetime
    }

    func upload(
        data: Data,
        userID: UUID,
        entryID: UUID,
        assetID: UUID,
        fileExtension: String,
        contentType: String
    ) async throws -> String {
        let path = MediaPathBuilder.objectPath(
            userID: userID,
            entryID: entryID,
            assetID: assetID,
            fileExtension: fileExtension
        )
        try await withRetry(maxAttempts: maxAttempts) {
            try await client.storage
                .from(bucket)
                .upload(
                    path,
                    data: data,
                    options: FileOptions(contentType: contentType, upsert: true)
                )
        }
        return path
    }

    func download(path: String) async throws -> Data {
        try await withRetry(maxAttempts: maxAttempts) {
            try await client.storage.from(bucket).download(path: path)
        }
    }

    func delete(path: String) async throws {
        try await withRetry(maxAttempts: maxAttempts) {
            _ = try await client.storage.from(bucket).remove(paths: [path])
        }
    }

    func signedURL(path: String, expiresIn: TimeInterval = 120) async throws -> URL {
        let lifetime = expiresIn > 0 ? expiresIn : signedURLLifetime
        let response = try await client.storage
            .from(bucket)
            .createSignedURL(path: path, expiresIn: Int(lifetime))
        return response
    }
}
#endif

actor UnavailableMediaService: MediaServing {
    func upload(
        data: Data,
        userID: UUID,
        entryID: UUID,
        assetID: UUID,
        fileExtension: String,
        contentType: String
    ) async throws -> String {
        throw MediaServiceError.notConfigured
    }

    func download(path: String) async throws -> Data {
        throw MediaServiceError.notConfigured
    }

    func delete(path: String) async throws {
        throw MediaServiceError.deleteFailed
    }

    func signedURL(path: String, expiresIn: TimeInterval) async throws -> URL {
        throw MediaServiceError.notConfigured
    }
}

/// Retries transient failures with exponential backoff.
func withRetry<T>(
    maxAttempts: Int,
    initialDelay: TimeInterval = 0.4,
    operation: @Sendable () async throws -> T
) async throws -> T {
    var attempt = 0
    var delay = initialDelay
    var lastError: Error?
    while attempt < maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            attempt += 1
            if attempt >= maxAttempts { break }
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            delay *= 2
        }
    }
    throw lastError ?? MediaServiceError.uploadFailed
}
