import Foundation

/// Exports local Evidence data to a temporary archive folder / zip-compatible package.
@MainActor
protocol ExportServing {
    func exportLocalArchive() async throws -> URL
}

enum ExportServiceError: Error, LocalizedError, Sendable {
    case failedToCreateDirectory
    case failedToEncode
    case failedToArchive

    var errorDescription: String? {
        switch self {
        case .failedToCreateDirectory:
            return "Could not create an export folder."
        case .failedToEncode:
            return "Could not encode your collection for export."
        case .failedToArchive:
            return "Could not finish the export archive."
        }
    }
}

struct EvidenceExportPayload: Codable, Sendable {
    var exportedAt: Date
    var profile: AppProfileExport?
    var entries: [EvidenceEntryExport]
    var tags: [EvidenceTagExport]
    var categories: [CategoryExport]
    var checkIns: [CheckInExport]
    var feedback: [FeedbackExport]
    var reminders: ReminderExport?
    var meaningfulDates: [MeaningfulDateExport]
}

struct AppProfileExport: Codable, Sendable {
    var id: UUID
    var displayName: String?
    var selectedUseCases: [String]
    var appLockEnabled: Bool
    var notificationPreviewMode: String
    var cloudSyncEnabled: Bool
    var onboardingCompletedAt: Date?
    var lastSuccessfulSyncAt: Date?
}

struct EvidenceEntryExport: Codable, Sendable {
    var id: UUID
    var title: String
    var bodyText: String?
    var entryType: String
    var sourceType: String
    var sourceName: String?
    var meaningPromptAnswer: String
    var isFavorite: Bool
    var isArchived: Bool
    var isSensitive: Bool
    var localImageFileName: String?
    var accessibilityDescription: String?
    var createdAt: Date
    var updatedAt: Date
    var tagIDs: [UUID]
    var categoryIDs: [UUID]
}

struct EvidenceTagExport: Codable, Sendable {
    var id: UUID
    var name: String
    var tagType: String
    var isSystemTag: Bool
}

struct CategoryExport: Codable, Sendable {
    var id: UUID
    var name: String
    var iconName: String?
    var sortOrder: Int
}

struct CheckInExport: Codable, Sendable {
    var id: UUID
    var emotion: String
    var intensity: Int?
    var supportNeed: String?
    var createdAt: Date
    var completedAt: Date?
    var safetyState: String
}

struct FeedbackExport: Codable, Sendable {
    var id: UUID
    var response: String
    var evidenceEntryID: UUID?
    var guidedContentID: UUID?
    var emotionAtTime: String?
    var supportNeedAtTime: String?
    var createdAt: Date
}

struct ReminderExport: Codable, Sendable {
    var isEnabled: Bool
    var selectedWeekdays: [Int]
    var deliveryHour: Int
    var deliveryMinute: Int
    var frequency: String
}

struct MeaningfulDateExport: Codable, Sendable {
    var id: UUID
    var evidenceEntryID: UUID
    var date: Date
    var recurrence: String
    var enabled: Bool
    var label: String?
}

/// Builds a temporary export directory containing `export.json` and an `images/` folder.
/// Also writes a simple ZIP when possible via Foundation file coordination.
@MainActor
struct ExportService: ExportServing {
    var entryRepository: any EvidenceEntryRepository
    var tagRepository: any TagRepository
    var categoryRepository: any CategoryRepository
    var checkInRepository: any CheckInRepository
    var feedbackRepository: any FeedbackRepository
    var profileRepository: any ProfileRepository
    var reminderRepository: any ReminderRepository
    var meaningfulDateRepository: any MeaningfulDateRepository
    var imageStorage: any ImageStorageServing
    var fileManager: FileManager = .default
    var dateProvider: any DateProviding = SystemDateProvider()

    func exportLocalArchive() async throws -> URL {
        let stamp = ISO8601DateFormatter().string(from: dateProvider.now)
            .replacingOccurrences(of: ":", with: "-")
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("EvidenceExport-\(stamp)", isDirectory: true)
        let imagesDir = root.appendingPathComponent("images", isDirectory: true)

        do {
            if fileManager.fileExists(atPath: root.path) {
                try fileManager.removeItem(at: root)
            }
            try fileManager.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        } catch {
            throw ExportServiceError.failedToCreateDirectory
        }

        let entries = try await entryRepository.fetchAll(includeArchived: true)
        let tags = try await tagRepository.fetchAll()
        let categories = try await categoryRepository.fetchAll()
        let checkIns = try await checkInRepository.fetchAll()
        let feedback = try await feedbackRepository.fetchAll()
        let profile = try await profileRepository.fetchProfile()
        let reminder = try await reminderRepository.fetchSchedule()
        let meaningful = try await meaningfulDateRepository.fetchAll()

        let payload = EvidenceExportPayload(
            exportedAt: dateProvider.now,
            profile: profile.map {
                AppProfileExport(
                    id: $0.id,
                    displayName: $0.displayName,
                    selectedUseCases: $0.selectedUseCases.map(\.rawValue),
                    appLockEnabled: $0.appLockEnabled,
                    notificationPreviewMode: $0.notificationPreviewMode.rawValue,
                    cloudSyncEnabled: $0.cloudSyncEnabled,
                    onboardingCompletedAt: $0.onboardingCompletedAt,
                    lastSuccessfulSyncAt: $0.lastSuccessfulSyncAt
                )
            },
            entries: entries.map { entry in
                EvidenceEntryExport(
                    id: entry.id,
                    title: entry.title,
                    bodyText: entry.bodyText,
                    entryType: entry.entryType.rawValue,
                    sourceType: entry.sourceType.rawValue,
                    sourceName: entry.sourceName,
                    meaningPromptAnswer: entry.meaningPromptAnswer,
                    isFavorite: entry.isFavorite,
                    isArchived: entry.isArchived,
                    isSensitive: entry.isSensitive,
                    localImageFileName: entry.localImageFileName,
                    accessibilityDescription: entry.accessibilityDescription,
                    createdAt: entry.createdAt,
                    updatedAt: entry.updatedAt,
                    tagIDs: entry.tags.map(\.id),
                    categoryIDs: entry.categories.map(\.id)
                )
            },
            tags: tags.map {
                EvidenceTagExport(
                    id: $0.id,
                    name: $0.name,
                    tagType: $0.tagType.rawValue,
                    isSystemTag: $0.isSystemTag
                )
            },
            categories: categories.map {
                CategoryExport(
                    id: $0.id,
                    name: $0.name,
                    iconName: $0.iconName,
                    sortOrder: $0.sortOrder
                )
            },
            checkIns: checkIns.map {
                CheckInExport(
                    id: $0.id,
                    emotion: $0.emotion.rawValue,
                    intensity: $0.intensity,
                    supportNeed: $0.supportNeed?.rawValue,
                    createdAt: $0.createdAt,
                    completedAt: $0.completedAt,
                    safetyState: $0.safetyState.rawValue
                )
            },
            feedback: feedback.map {
                FeedbackExport(
                    id: $0.id,
                    response: $0.response.rawValue,
                    evidenceEntryID: $0.evidenceEntryID,
                    guidedContentID: $0.guidedContentID,
                    emotionAtTime: $0.emotionAtTime?.rawValue,
                    supportNeedAtTime: $0.supportNeedAtTime?.rawValue,
                    createdAt: $0.createdAt
                )
            },
            reminders: reminder.map {
                ReminderExport(
                    isEnabled: $0.isEnabled,
                    selectedWeekdays: $0.selectedWeekdays,
                    deliveryHour: $0.deliveryHour,
                    deliveryMinute: $0.deliveryMinute,
                    frequency: $0.frequency.rawValue
                )
            },
            meaningfulDates: meaningful.map {
                MeaningfulDateExport(
                    id: $0.id,
                    evidenceEntryID: $0.evidenceEntryID,
                    date: $0.date,
                    recurrence: $0.recurrence.rawValue,
                    enabled: $0.enabled,
                    label: $0.label
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(payload)
            try data.write(to: root.appendingPathComponent("export.json"), options: .atomic)
        } catch {
            throw ExportServiceError.failedToEncode
        }

        // Copy images by filename only — never log image content.
        for entry in entries {
            guard let name = entry.localImageFileName else { continue }
            let source = imageStorage.imagesDirectoryURL.appendingPathComponent(name)
            let dest = imagesDir.appendingPathComponent(name)
            if fileManager.fileExists(atPath: source.path) {
                try? fileManager.copyItem(at: source, to: dest)
            }
            let thumb = name.replacingOccurrences(of: "-display.jpg", with: "-thumb.jpg")
            let thumbSource = imageStorage.imagesDirectoryURL.appendingPathComponent(thumb)
            let thumbDest = imagesDir.appendingPathComponent(thumb)
            if fileManager.fileExists(atPath: thumbSource.path) {
                try? fileManager.copyItem(at: thumbSource, to: thumbDest)
            }
        }

        let readme = """
        Evidence export
        ===============
        This folder contains export.json (structured data) and images/ (local media copies).

        To create a ZIP on macOS or iOS, compress this folder with the Share sheet or Finder.
        Paths and filenames intentionally avoid embedding private text beyond what you exported.
        """
        try? readme.data(using: .utf8)?.write(to: root.appendingPathComponent("README.txt"))

        // Produce a zip archive beside the folder using a simple stored-file ZIP writer.
        let zipURL = root.appendingPathExtension("zip")
        try SimpleZipWriter.zipDirectory(at: root, to: zipURL)
        return zipURL
    }
}

// MARK: - Minimal ZIP writer (store method, no external dependency)

enum SimpleZipWriter {
    static func zipDirectory(at sourceDirectory: URL, to destinationZIP: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destinationZIP.path) {
            try fileManager.removeItem(at: destinationZIP)
        }

        var files: [(relative: String, url: URL)] = []
        let enumerator = fileManager.enumerator(
            at: sourceDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        while let url = enumerator?.nextObject() as? URL {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else {
                continue
            }
            let relative = url.path.replacingOccurrences(of: sourceDirectory.path + "/", with: "")
            files.append((relative, url))
        }

        FileManager.default.createFile(atPath: destinationZIP.path, contents: nil)
        let handle = try FileHandle(forWritingTo: destinationZIP)
        defer { try? handle.close() }

        var centralDirectory = Data()
        var offset: UInt32 = 0

        for file in files {
            let data = try Data(contentsOf: file.url)
            let nameData = Data(file.relative.utf8)
            let crc = crc32(data)
            let localHeader = zipLocalFileHeader(
                fileName: nameData,
                crc32: crc,
                compressedSize: UInt32(data.count),
                uncompressedSize: UInt32(data.count)
            )
            try handle.write(contentsOf: localHeader)
            try handle.write(contentsOf: nameData)
            try handle.write(contentsOf: data)

            let central = zipCentralDirectoryHeader(
                fileName: nameData,
                crc32: crc,
                compressedSize: UInt32(data.count),
                uncompressedSize: UInt32(data.count),
                localHeaderOffset: offset
            )
            centralDirectory.append(central)
            centralDirectory.append(nameData)
            offset += UInt32(localHeader.count + nameData.count + data.count)
        }

        let centralOffset = offset
        try handle.write(contentsOf: centralDirectory)
        let end = zipEndOfCentralDirectory(
            entryCount: UInt16(files.count),
            centralDirectorySize: UInt32(centralDirectory.count),
            centralDirectoryOffset: centralOffset
        )
        try handle.write(contentsOf: end)
    }

    private static func zipLocalFileHeader(
        fileName: Data,
        crc32: UInt32,
        compressedSize: UInt32,
        uncompressedSize: UInt32
    ) -> Data {
        var data = Data()
        data.appendUInt32(0x04034b50) // local file header signature
        data.appendUInt16(20) // version needed
        data.appendUInt16(0) // flags
        data.appendUInt16(0) // compression method: store
        data.appendUInt16(0) // mod time
        data.appendUInt16(0) // mod date
        data.appendUInt32(crc32)
        data.appendUInt32(compressedSize)
        data.appendUInt32(uncompressedSize)
        data.appendUInt16(UInt16(fileName.count))
        data.appendUInt16(0) // extra length
        return data
    }

    private static func zipCentralDirectoryHeader(
        fileName: Data,
        crc32: UInt32,
        compressedSize: UInt32,
        uncompressedSize: UInt32,
        localHeaderOffset: UInt32
    ) -> Data {
        var data = Data()
        data.appendUInt32(0x02014b50)
        data.appendUInt16(20)
        data.appendUInt16(20)
        data.appendUInt16(0)
        data.appendUInt16(0)
        data.appendUInt16(0)
        data.appendUInt16(0)
        data.appendUInt32(crc32)
        data.appendUInt32(compressedSize)
        data.appendUInt32(uncompressedSize)
        data.appendUInt16(UInt16(fileName.count))
        data.appendUInt16(0)
        data.appendUInt16(0)
        data.appendUInt16(0)
        data.appendUInt16(0)
        data.appendUInt32(0)
        data.appendUInt32(localHeaderOffset)
        return data
    }

    private static func zipEndOfCentralDirectory(
        entryCount: UInt16,
        centralDirectorySize: UInt32,
        centralDirectoryOffset: UInt32
    ) -> Data {
        var data = Data()
        data.appendUInt32(0x06054b50)
        data.appendUInt16(0)
        data.appendUInt16(0)
        data.appendUInt16(entryCount)
        data.appendUInt16(entryCount)
        data.appendUInt32(centralDirectorySize)
        data.appendUInt32(centralDirectoryOffset)
        data.appendUInt16(0)
        return data
    }

    /// IEEE CRC-32 used by ZIP.
    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ crc32Table[index]
        }
        return crc ^ 0xFFFFFFFF
    }

    private static let crc32Table: [UInt32] = {
        (0..<256).map { index -> UInt32 in
            var crc = UInt32(index)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc >>= 1
                }
            }
            return crc
        }
    }()
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }
}
