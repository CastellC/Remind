import Foundation
import UIKit

/// Saves, loads, and cleans up local evidence images.
protocol ImageStorageServing: Sendable {
    var imagesDirectoryURL: URL { get }
    func saveImageData(_ data: Data) async throws -> StoredImageFilenames
    func loadDisplayImage(fileName: String) async throws -> UIImage?
    func loadThumbnail(fileName: String) async throws -> UIImage?
    func deleteImages(displayFileName: String?, thumbnailFileName: String?) async throws
    func cleanupOrphans(knownFileNames: Set<String>) async throws -> Int
}

struct StoredImageFilenames: Equatable, Sendable {
    let displayFileName: String
    let thumbnailFileName: String
}

enum ImageStorageError: Error, LocalizedError, Sendable {
    case invalidImageData
    case writeFailed
    case directoryUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "The selected image could not be read."
        case .writeFailed:
            return "The image could not be saved."
        case .directoryUnavailable:
            return "Image storage is unavailable."
        }
    }
}

/// Stores JPEG display and thumbnail files under Application Support/EvidenceImages/.
actor LocalImageStorageService: ImageStorageServing {
    private let fileManager: FileManager
    private let uuidProvider: UUIDProviding
    private let displayMaxDimension: CGFloat
    private let thumbnailMaxDimension: CGFloat
    private let displayCompression: CGFloat
    private let thumbnailCompression: CGFloat

    nonisolated let imagesDirectoryURL: URL

    init(
        fileManager: FileManager = .default,
        uuidProvider: UUIDProviding = SystemUUIDProvider(),
        displayMaxDimension: CGFloat = 1600,
        thumbnailMaxDimension: CGFloat = 400,
        displayCompression: CGFloat = 0.82,
        thumbnailCompression: CGFloat = 0.7
    ) throws {
        self.fileManager = fileManager
        self.uuidProvider = uuidProvider
        self.displayMaxDimension = displayMaxDimension
        self.thumbnailMaxDimension = thumbnailMaxDimension
        self.displayCompression = displayCompression
        self.thumbnailCompression = thumbnailCompression

        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = appSupport.appendingPathComponent("EvidenceImages", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try Self.applyFileProtection(to: directory)
        self.imagesDirectoryURL = directory
    }

    func saveImageData(_ data: Data) async throws -> StoredImageFilenames {
        guard let image = UIImage(data: data) else {
            throw ImageStorageError.invalidImageData
        }

        let id = uuidProvider.makeUUID().uuidString
        let displayName = "\(id)-display.jpg"
        let thumbName = "\(id)-thumb.jpg"

        let displayImage = Self.resized(image, maxDimension: displayMaxDimension)
        let thumbImage = Self.resized(image, maxDimension: thumbnailMaxDimension)

        guard
            let displayData = displayImage.jpegData(compressionQuality: displayCompression),
            let thumbData = thumbImage.jpegData(compressionQuality: thumbnailCompression)
        else {
            throw ImageStorageError.invalidImageData
        }

        let displayURL = imagesDirectoryURL.appendingPathComponent(displayName)
        let thumbURL = imagesDirectoryURL.appendingPathComponent(thumbName)

        do {
            try displayData.write(to: displayURL, options: [.atomic])
            try thumbData.write(to: thumbURL, options: [.atomic])
            try Self.applyFileProtection(to: displayURL)
            try Self.applyFileProtection(to: thumbURL)
        } catch {
            // Never log image bytes or paths that could reveal private content beyond filenames.
            throw ImageStorageError.writeFailed
        }

        return StoredImageFilenames(displayFileName: displayName, thumbnailFileName: thumbName)
    }

    func loadDisplayImage(fileName: String) async throws -> UIImage? {
        try loadImage(fileName: fileName)
    }

    func loadThumbnail(fileName: String) async throws -> UIImage? {
        try loadImage(fileName: fileName)
    }

    func deleteImages(displayFileName: String?, thumbnailFileName: String?) async throws {
        for name in [displayFileName, thumbnailFileName].compactMap({ $0 }) {
            let url = imagesDirectoryURL.appendingPathComponent(name)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }

    func cleanupOrphans(knownFileNames: Set<String>) async throws -> Int {
        let contents = try fileManager.contentsOfDirectory(
            at: imagesDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        var removed = 0
        for url in contents {
            let name = url.lastPathComponent
            if !knownFileNames.contains(name) {
                try fileManager.removeItem(at: url)
                removed += 1
            }
        }
        return removed
    }

    // MARK: - Private

    private func loadImage(fileName: String) throws -> UIImage? {
        let sanitized = (fileName as NSString).lastPathComponent
        guard !sanitized.isEmpty, sanitized == fileName else { return nil }
        let url = imagesDirectoryURL.appendingPathComponent(sanitized)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return UIImage(data: data)
    }

    private static func applyFileProtection(to url: URL) throws {
        try (url as NSURL).setResourceValue(
            URLFileProtection.completeUntilFirstUserAuthentication,
            forKey: .fileProtectionKey
        )
    }

    private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
