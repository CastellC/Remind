import XCTest
@testable import Evidence

final class ImageOrphanCleanupTests: XCTestCase {
    private var tempDirectory: URL!
    private let fileManager = FileManager.default

    override func setUp() {
        super.setUp()
        tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("EvidenceOrphanTests-\(UUID().uuidString)", isDirectory: true)
        try? fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? fileManager.removeItem(at: tempDirectory)
        tempDirectory = nil
        super.tearDown()
    }

    private func writeFile(named name: String, contents: String = "x") throws {
        let url = tempDirectory.appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
    }

    func testOrphanURLsDetectUnknownFiles() throws {
        try writeFile(named: "keep-display.jpg")
        try writeFile(named: "keep-thumb.jpg")
        try writeFile(named: "orphan-display.jpg")

        let orphans = try ImageOrphanCleanup.orphanURLs(
            in: tempDirectory,
            knownFileNames: ["keep-display.jpg", "keep-thumb.jpg"],
            fileManager: fileManager
        )

        XCTAssertEqual(orphans.map(\.lastPathComponent).sorted(), ["orphan-display.jpg"])
    }

    func testCleanupRemovesOnlyOrphans() throws {
        try writeFile(named: "a-display.jpg")
        try writeFile(named: "a-thumb.jpg")
        try writeFile(named: "b-display.jpg")
        try writeFile(named: "b-thumb.jpg")

        let removed = try ImageOrphanCleanup.cleanupOrphans(
            in: tempDirectory,
            knownFileNames: ["a-display.jpg", "a-thumb.jpg"],
            fileManager: fileManager
        )

        XCTAssertEqual(removed, 2)

        let remaining = try fileManager.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: nil
        ).map(\.lastPathComponent).sorted()

        XCTAssertEqual(remaining, ["a-display.jpg", "a-thumb.jpg"])
    }

    func testCleanupWithEmptyKnownRemovesAll() throws {
        try writeFile(named: "gone-display.jpg")
        try writeFile(named: "gone-thumb.jpg")

        let removed = try ImageOrphanCleanup.cleanupOrphans(
            in: tempDirectory,
            knownFileNames: [],
            fileManager: fileManager
        )
        XCTAssertEqual(removed, 2)

        let remaining = try fileManager.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: nil
        )
        XCTAssertTrue(remaining.isEmpty)
    }

    func testCleanupOnMissingDirectoryReturnsZero() throws {
        let missing = tempDirectory.appendingPathComponent("does-not-exist", isDirectory: true)
        let removed = try ImageOrphanCleanup.cleanupOrphans(
            in: missing,
            knownFileNames: ["anything.jpg"],
            fileManager: fileManager
        )
        XCTAssertEqual(removed, 0)
    }

    func testLocalImageStorageServiceUsesInjectedDirectory() async throws {
        let uuid = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
        let storage = try LocalImageStorageService(
            directoryURL: tempDirectory,
            uuidProvider: FixedUUIDProvider(uuids: [uuid])
        )

        XCTAssertEqual(storage.imagesDirectoryURL.path, tempDirectory.path)

        // Seed known + orphan files directly (avoid needing valid image bytes for save).
        try writeFile(named: "\(uuid.uuidString)-display.jpg")
        try writeFile(named: "\(uuid.uuidString)-thumb.jpg")
        try writeFile(named: "orphan.jpg")

        let known: Set<String> = [
            "\(uuid.uuidString)-display.jpg",
            "\(uuid.uuidString)-thumb.jpg"
        ]
        let removed = try await storage.cleanupOrphans(knownFileNames: known)
        XCTAssertEqual(removed, 1)

        let remaining = try fileManager.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: nil
        ).map(\.lastPathComponent).sorted()
        XCTAssertEqual(remaining.sorted(), known.sorted())
    }
}
