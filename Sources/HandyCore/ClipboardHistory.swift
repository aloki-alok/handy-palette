import Foundation
import Darwin

public struct ClipboardEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let text: String
    public let capturedAt: Date

    public init(id: UUID = UUID(), text: String, capturedAt: Date = .now) {
        self.id = id
        self.text = text
        self.capturedAt = capturedAt
    }
}

public struct ClipboardHistory: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public static let maximumEntries = 50
    public static let maximumTextBytes = 20_000
    public static let sensitivePasteboardTypeNames: Set<String> = [
        "org.nspasteboard.ConcealedType",
        "org.nspasteboard.TransientType",
        "de.petermaurer.TransientPasteboardType",
        "com.agilebits.onepassword"
    ]

    public let version: Int
    public private(set) var entries: [ClipboardEntry]

    public init(version: Int = Self.currentVersion, entries: [ClipboardEntry] = []) {
        self.version = version
        self.entries = Array(entries.prefix(Self.maximumEntries))
    }

    private enum CodingKeys: String, CodingKey { case version, entries }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
        guard version == Self.currentVersion else {
            throw DecodingError.dataCorruptedError(forKey: .version, in: values, debugDescription: "Unsupported clipboard history version")
        }
        let decodedEntries = try values.decode([ClipboardEntry].self, forKey: .entries)
        guard decodedEntries.count <= Self.maximumEntries,
              decodedEntries.allSatisfy({
                  !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      && $0.text.utf8.count <= Self.maximumTextBytes
              }) else {
            throw DecodingError.dataCorruptedError(forKey: .entries, in: values, debugDescription: "Clipboard history contains invalid entries")
        }
        entries = decodedEntries
    }

    public static func allowsCapture(pasteboardTypeNames: [String]) -> Bool {
        sensitivePasteboardTypeNames.isDisjoint(with: pasteboardTypeNames)
    }

    @discardableResult
    public mutating func capture(_ text: String, at date: Date = .now) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, text.utf8.count <= Self.maximumTextBytes, entries.first?.text != text else { return false }
        entries.insert(ClipboardEntry(text: text, capturedAt: date), at: 0)
        if entries.count > Self.maximumEntries { entries.removeLast(entries.count - Self.maximumEntries) }
        return true
    }

    public func matches(_ query: String) -> [ClipboardEntry] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return entries }
        return entries.filter { $0.text.localizedCaseInsensitiveContains(normalized) }
    }
}

public struct ClipboardHistoryRepository {
    public let url: URL

    public init(url: URL = Self.defaultURL) { self.url = url }

    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Handy", isDirectory: true)
            .appendingPathComponent("clipboard-history.json")
    }

    public func load() throws -> ClipboardHistory {
        guard FileManager.default.fileExists(atPath: url.path) else { return ClipboardHistory() }
        let data = try Data(contentsOf: url)
        guard data.count <= 1_100_000 else { throw CocoaError(.fileReadTooLarge) }
        return try JSONDecoder().decode(ClipboardHistory.self, from: data)
    }

    public func save(_ history: ClipboardHistory) throws {
        try withExclusiveLock { try saveUnlocked(history) }
    }

    public func update(_ change: (inout ClipboardHistory) throws -> Void) throws -> ClipboardHistory {
        try withExclusiveLock {
            var history = try load()
            try change(&history)
            try saveUnlocked(history)
            return history
        }
    }

    private func saveUnlocked(_ history: ClipboardHistory) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(history).write(to: url, options: .atomic)
        if url == Self.defaultURL {
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
    }

    private func withExclusiveLock<T>(_ operation: () throws -> T) throws -> T {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let lockURL = directory.appendingPathComponent(".clipboard-history.lock")
        let descriptor = Darwin.open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw POSIXError(.EIO) }
        defer { Darwin.close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw POSIXError(.EIO) }
        defer { flock(descriptor, LOCK_UN) }
        return try operation()
    }
}
