import Foundation

/// Pure orphan-file cleanup for evidence image directories.
enum ImageOrphanCleanup {
    /// Lists file URLs in `directory` whose last path component is not in `knownFileNames`.
    static func orphanURLs(
        in directory: URL,
        knownFileNames: Set<String>,
        fileManager: FileManager = .default
    ) throws -> [URL] {
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return contents.filter { url in
            !knownFileNames.contains(url.lastPathComponent)
        }
    }

    /// Deletes orphan files and returns the count removed.
    @discardableResult
    static func cleanupOrphans(
        in directory: URL,
        knownFileNames: Set<String>,
        fileManager: FileManager = .default
    ) throws -> Int {
        let orphans = try orphanURLs(
            in: directory,
            knownFileNames: knownFileNames,
            fileManager: fileManager
        )
        var removed = 0
        for url in orphans {
            try fileManager.removeItem(at: url)
            removed += 1
        }
        return removed
    }
}
