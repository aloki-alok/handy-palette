import Foundation

public struct HandyLibrary: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var items: [HandyItem]

    public init(version: Int, items: [HandyItem]) {
        self.version = version
        self.items = items
    }

    public static let starter = HandyLibrary(version: currentVersion, items: [
        HandyItem(id: "shrug", text: "¯\\_(ツ)_/¯", title: "Shrug", tags: ["kaomoji", "confused"], isPinned: true),
        HandyItem(id: "happy", text: "(◕‿◕)", title: "Happy", tags: ["kaomoji", "happy"], isPinned: true),
        HandyItem(id: "table-flip", text: "(╯°□°）╯︵ ┻━┻", title: "Table flip", tags: ["kaomoji", "angry"], isPinned: false),
        HandyItem(id: "sparkles", text: "✨", title: "Sparkles", tags: ["emoji", "celebrate"], isPinned: true),
        HandyItem(id: "wave", text: "👋", title: "Wave", tags: ["emoji", "hello"], isPinned: false),
        HandyItem(id: "thanks", text: "Thank you!", title: "Thanks", tags: ["snippet", "reply"], isPinned: false)
    ])

    public func matches(_ query: String) -> [HandyItem] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return items.sorted { lhs, rhs in
            let lhsScore = lhs.searchScore(for: normalized)
            let rhsScore = rhs.searchScore(for: normalized)
            if lhsScore != rhsScore { return lhsScore > rhsScore }
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            if lhs.useCount != rhs.useCount { return lhs.useCount > rhs.useCount }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }.filter { normalized.isEmpty || $0.searchScore(for: normalized) > 0 }
    }
}

public struct HandyItem: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let text: String
    public let title: String
    public let tags: [String]
    public let isPinned: Bool
    public var useCount: Int

    public init(id: String, text: String, title: String, tags: [String], isPinned: Bool, useCount: Int = 0) {
        self.id = id
        self.text = text
        self.title = title
        self.tags = tags
        self.isPinned = isPinned
        self.useCount = useCount
    }

    public func searchScore(for query: String) -> Int {
        guard !query.isEmpty else { return 1 }
        let title = title.lowercased()
        let tags = tags.joined(separator: " ").lowercased()
        if title == query { return 100 }
        if title.hasPrefix(query) { return 75 }
        if tags.contains(query) { return 50 }
        if text.contains(query) { return 25 }
        return 0
    }
}

public enum LibraryRepositoryError: LocalizedError {
    case unsupportedVersion(Int)
    case fileTooLarge
    case tooManyItems
    case invalidID(String)
    case invalidTitle(String)
    case invalidText(String)
    case invalidTags(String)
    case invalidUseCount(String)
    case emptyText(String)
    case duplicateID(String)
    case duplicateTitle(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version): return "Handy library version \(version) is newer than this app supports."
        case .fileTooLarge: return "The Handy library is larger than 5 MB."
        case .tooManyItems: return "The Handy library has more than 5,000 items."
        case .invalidID(let id): return "Item id \(id) is invalid."
        case .invalidTitle(let id): return "Item \(id) has an invalid title."
        case .invalidText(let id): return "Item \(id) has too much text."
        case .invalidTags(let id): return "Item \(id) has invalid tags."
        case .invalidUseCount(let id): return "Item \(id) has an invalid use count."
        case .emptyText(let id): return "Item \(id) has no text."
        case .duplicateID(let id): return "The item id \(id) appears more than once."
        case .duplicateTitle(let title): return "The item title \(title) appears more than once."
        }
    }
}

public struct LibraryRepository {
    public let url: URL
    private let fileManager: FileManager

    public init(url: URL = LibraryRepository.defaultURL, fileManager: FileManager = .default) {
        self.url = url
        self.fileManager = fileManager
    }

    public static var defaultURL: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Handy", isDirectory: true)
        return folder.appendingPathComponent("library.json")
    }

    public func load() throws -> HandyLibrary {
        guard fileManager.fileExists(atPath: url.path) else {
            try save(.starter)
            return .starter
        }
        return try readLibrary(from: url)
    }

    public func save(_ library: HandyLibrary) throws {
        try validate(library)
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        if directory == LibraryRepository.defaultURL.deletingLastPathComponent() {
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        }
        try libraryData(library).write(to: url, options: .atomic)
        if directory == LibraryRepository.defaultURL.deletingLastPathComponent() {
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
    }

    public func importLibrary(from sourceURL: URL) throws -> HandyLibrary {
        let imported = try readLibrary(from: sourceURL)
        try save(imported)
        return imported
    }

    public func exportLibrary(to destinationURL: URL) throws {
        let library = try load()
        try libraryData(library).write(to: destinationURL, options: .atomic)
    }

    private func validate(_ library: HandyLibrary) throws {
        guard library.version == HandyLibrary.currentVersion else { throw LibraryRepositoryError.unsupportedVersion(library.version) }
        guard library.items.count <= 5_000 else { throw LibraryRepositoryError.tooManyItems }
        var ids = Set<String>()
        var titles = Set<String>()
        for item in library.items {
            guard item.id.utf8.count > 0 && item.id.utf8.count <= 80 else { throw LibraryRepositoryError.invalidID(item.id) }
            guard item.title.trimmingCharacters(in: .whitespacesAndNewlines).utf8.count > 0 && item.title.utf8.count <= 120 else { throw LibraryRepositoryError.invalidTitle(item.id) }
            guard !item.text.isEmpty else { throw LibraryRepositoryError.emptyText(item.id) }
            guard item.text.utf8.count <= 10_000 else { throw LibraryRepositoryError.invalidText(item.id) }
            guard item.tags.count <= 12 && item.tags.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.utf8.count <= 40 }) else {
                throw LibraryRepositoryError.invalidTags(item.id)
            }
            guard (0...1_000_000).contains(item.useCount) else { throw LibraryRepositoryError.invalidUseCount(item.id) }
            guard ids.insert(item.id).inserted else { throw LibraryRepositoryError.duplicateID(item.id) }
            guard titles.insert(item.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))).inserted else {
                throw LibraryRepositoryError.duplicateTitle(item.title)
            }
        }
    }

    private func readLibrary(from sourceURL: URL) throws -> HandyLibrary {
        let size = (try fileManager.attributesOfItem(atPath: sourceURL.path)[.size] as? NSNumber)?.intValue ?? 0
        guard size <= 5_000_000 else { throw LibraryRepositoryError.fileTooLarge }
        let library = try JSONDecoder().decode(HandyLibrary.self, from: Data(contentsOf: sourceURL))
        try validate(library)
        return library
    }

    private func libraryData(_ library: HandyLibrary) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(library)
    }
}
