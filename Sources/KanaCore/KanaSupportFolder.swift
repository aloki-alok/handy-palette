import Foundation

/// Resolves the app support folder, adopting the pre-rename "Handy" folder once so an
/// existing library and clipboard history survive the rename to Kana.
public enum KanaSupportFolder {
    static let currentName = "Kana"
    static let legacyName = "Handy"

    public static func url(for fileName: String) -> URL {
        folder().appendingPathComponent(fileName)
    }

    /// `root` is injectable so the migration can be checked without touching the real support folder.
    public static func folder(root: URL? = nil, fileManager: FileManager = .default) -> URL {
        let root = root ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let current = root.appendingPathComponent(currentName, isDirectory: true)
        let legacy = root.appendingPathComponent(legacyName, isDirectory: true)
        guard !fileManager.fileExists(atPath: current.path),
              fileManager.fileExists(atPath: legacy.path) else { return current }
        // A failed move leaves the legacy folder untouched, so the next launch retries.
        try? fileManager.moveItem(at: legacy, to: current)
        return fileManager.fileExists(atPath: current.path) ? current : legacy
    }
}
