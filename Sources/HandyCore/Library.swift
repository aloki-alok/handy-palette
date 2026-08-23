import Foundation
import Darwin

public enum HandyResources {
    public static func starterCatalogURL(appResourceURL: URL? = Bundle.main.resourceURL) -> URL? {
        if let appResourceURL {
            let appCatalogURL = appResourceURL.appendingPathComponent("starter-library.json")
            if FileManager.default.isReadableFile(atPath: appCatalogURL.path) {
                return appCatalogURL
            }
        }
        return Bundle.module.url(forResource: "starter-library", withExtension: "json")
    }
}

public struct HandyLibrary: Codable, Equatable, Sendable {
    public static let currentVersion = 2

    public var version: Int
    public var catalogRevision: Int
    public var categories: [HandyCategory]
    public var items: [HandyItem]

    public init(version: Int, catalogRevision: Int = 0, categories: [HandyCategory] = [], items: [HandyItem]) {
        self.version = version
        self.catalogRevision = catalogRevision
        self.items = items
        self.categories = categories.isEmpty ? Self.categoriesInferred(from: items) : categories
    }

    private enum CodingKeys: String, CodingKey { case version, catalogRevision, categories, items }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        catalogRevision = try values.decodeIfPresent(Int.self, forKey: .catalogRevision) ?? 0
        items = try values.decode([HandyItem].self, forKey: .items)
        categories = try values.decodeIfPresent([HandyCategory].self, forKey: .categories) ?? Self.categoriesInferred(from: items)
    }

    public static let starter: HandyLibrary = {
        guard let url = HandyResources.starterCatalogURL(),
              let data = try? Data(contentsOf: url),
              let library = try? JSONDecoder().decode(HandyLibrary.self, from: data) else {
            fatalError("HandyCore is missing its versioned starter library resource.")
        }
        return library
    }()

    public func matches(_ query: String, limit: Int? = nil) -> [HandyItem] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let categoriesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let ranked = items.compactMap { item -> (item: HandyItem, score: Int)? in
            let score = item.searchScore(for: normalized, category: categoriesByID[item.categoryID])
            return normalized.isEmpty || score > 0 ? (item, score) : nil
        }.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.item.isPinned != rhs.item.isPinned { return lhs.item.isPinned }
            if lhs.item.useCount != rhs.item.useCount { return lhs.item.useCount > rhs.item.useCount }
            return lhs.item.title.localizedCaseInsensitiveCompare(rhs.item.title) == .orderedAscending
        }
        let values = ranked.map(\.item)
        guard let limit else { return values }
        return Array(values.prefix(limit))
    }

    public func recentItems(limit: Int = 10) -> [HandyItem] {
        Array(items.filter { $0.lastUsedAt != nil }.sorted {
            if $0.lastUsedAt != $1.lastUsedAt { return ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            if $0.useCount != $1.useCount { return $0.useCount > $1.useCount }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }.prefix(limit))
    }

    public mutating func recordUse(of id: String, at date: Date = .now) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].useCount = min(items[index].useCount + 1, 1_000_000)
        items[index].lastUsedAt = date
    }

    public mutating func togglePinned(id: String) -> Bool? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        items[index].isPinned.toggle()
        return items[index].isPinned
    }

    public mutating func mergeCatalogUpdates(from catalog: HandyLibrary) -> Bool {
        guard catalogRevision < catalog.catalogRevision else { return false }
        let existingCategories = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let catalogIDs = Set(catalog.categories.map(\.id))
        categories = catalog.categories + categories.filter { !catalogIDs.contains($0.id) }
        for (index, category) in categories.enumerated() where !catalogIDs.contains(category.id) {
            categories[index] = existingCategories[category.id] ?? category
        }
        let existingItemIDs = Set(items.map(\.id))
        items.append(contentsOf: catalog.items.filter { !existingItemIDs.contains($0.id) })
        catalogRevision = catalog.catalogRevision
        return true
    }

    private static func categoriesInferred(from items: [HandyItem]) -> [HandyCategory] {
        Array(Set(items.map(\.categoryID))).sorted().enumerated().map { index, id in
            HandyCategory(id: id, title: id.replacingOccurrences(of: "-", with: " ").capitalized, symbol: "square.grid.2x2", webSymbol: "squares-four", order: index)
        }
    }
}

public struct HandyCategory: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let symbol: String
    public let displayGlyph: String?
    public let webSymbol: String?
    public let order: Int
    public let capabilities: [String]

    public init(id: String, title: String, symbol: String, displayGlyph: String? = nil, webSymbol: String? = nil, order: Int, capabilities: [String] = []) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.displayGlyph = displayGlyph
        self.webSymbol = webSymbol
        self.order = order
        self.capabilities = capabilities
    }

    private enum CodingKeys: String, CodingKey { case id, title, symbol, displayGlyph, webSymbol, order, capabilities }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        symbol = try values.decode(String.self, forKey: .symbol)
        displayGlyph = try values.decodeIfPresent(String.self, forKey: .displayGlyph)
        webSymbol = try values.decodeIfPresent(String.self, forKey: .webSymbol)
        order = try values.decode(Int.self, forKey: .order)
        capabilities = try values.decodeIfPresent([String].self, forKey: .capabilities) ?? []
    }
}

public struct HandyItem: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let text: String
    public let title: String
    public let tags: [String]
    public let categoryID: String
    public var isPinned: Bool
    public var useCount: Int
    public var lastUsedAt: Date?

    public init(id: String, text: String, title: String, tags: [String], categoryID: String? = nil, isPinned: Bool, useCount: Int = 0, lastUsedAt: Date? = nil) {
        self.id = id
        self.text = text
        self.title = title
        self.tags = tags
        self.categoryID = categoryID ?? Self.inferLegacyCategory(from: tags)
        self.isPinned = isPinned
        self.useCount = useCount
        self.lastUsedAt = lastUsedAt
    }

    private enum CodingKeys: String, CodingKey { case id, text, title, tags, categoryID, kind, isPinned, useCount, lastUsedAt }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        text = try values.decode(String.self, forKey: .text)
        title = try values.decode(String.self, forKey: .title)
        tags = try values.decode([String].self, forKey: .tags)
        categoryID = try values.decodeIfPresent(String.self, forKey: .categoryID)
            ?? values.decodeIfPresent(String.self, forKey: .kind)
            ?? Self.inferLegacyCategory(from: tags)
        isPinned = try values.decode(Bool.self, forKey: .isPinned)
        useCount = try values.decodeIfPresent(Int.self, forKey: .useCount) ?? 0
        lastUsedAt = try values.decodeIfPresent(Date.self, forKey: .lastUsedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(text, forKey: .text)
        try values.encode(title, forKey: .title)
        try values.encode(tags, forKey: .tags)
        try values.encode(categoryID, forKey: .categoryID)
        try values.encode(isPinned, forKey: .isPinned)
        try values.encode(useCount, forKey: .useCount)
        try values.encodeIfPresent(lastUsedAt, forKey: .lastUsedAt)
    }

    private static func inferLegacyCategory(from tags: [String]) -> String {
        if let type = tags.first(where: { ["emoji", "snippet", "kaomoji"].contains($0.lowercased()) }) { return type.lowercased() }
        return "kaomoji"
    }

    public func searchScore(for query: String, category: HandyCategory? = nil) -> Int {
        guard !query.isEmpty else { return 1 }
        let title = title.lowercased()
        let tags = ([categoryID, category?.title ?? ""] + tags).joined(separator: " ").lowercased()
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
    case invalidCategory(String)

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
        case .invalidCategory(let id): return "The category \(id) is invalid or missing."
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
        try withExclusiveLock {
            guard fileManager.fileExists(atPath: url.path) else {
                try saveUnlocked(.starter)
                return .starter
            }
            var library = try readLibrary(from: url)
            if library.mergeCatalogUpdates(from: .starter) { try saveUnlocked(library) }
            return library
        }
    }

    public func save(_ library: HandyLibrary) throws {
        try withExclusiveLock { try saveUnlocked(library) }
    }

    public func update(_ change: (inout HandyLibrary) throws -> Void) throws -> HandyLibrary {
        try withExclusiveLock {
            var library: HandyLibrary
            if fileManager.fileExists(atPath: url.path) {
                library = try readLibrary(from: url)
                _ = library.mergeCatalogUpdates(from: .starter)
            } else {
                library = .starter
            }
            try change(&library)
            try saveUnlocked(library)
            return library
        }
    }

    private func saveUnlocked(_ library: HandyLibrary) throws {
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

    private func withExclusiveLock<T>(_ operation: () throws -> T) throws -> T {
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let lockURL = directory.appendingPathComponent(".library.lock")
        let descriptor = Darwin.open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw POSIXError(.EIO) }
        defer { Darwin.close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw POSIXError(.EIO) }
        defer { flock(descriptor, LOCK_UN) }
        return try operation()
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
        guard library.categories.count <= 100 else { throw LibraryRepositoryError.invalidCategory("limit") }
        let categoryIDs = Set(library.categories.map(\.id))
        guard categoryIDs.count == library.categories.count else { throw LibraryRepositoryError.invalidCategory("duplicate") }
        for category in library.categories {
            guard !category.id.isEmpty, category.id.utf8.count <= 80,
                  !category.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  category.title.utf8.count <= 80,
                  !category.symbol.isEmpty, category.symbol.utf8.count <= 80 else {
                throw LibraryRepositoryError.invalidCategory(category.id)
            }
        }
        var ids = Set<String>()
        for item in library.items {
            guard item.id.utf8.count > 0 && item.id.utf8.count <= 80 else { throw LibraryRepositoryError.invalidID(item.id) }
            guard item.title.trimmingCharacters(in: .whitespacesAndNewlines).utf8.count > 0 && item.title.utf8.count <= 120 else { throw LibraryRepositoryError.invalidTitle(item.id) }
            guard !item.text.isEmpty else { throw LibraryRepositoryError.emptyText(item.id) }
            guard item.text.utf8.count <= 10_000 else { throw LibraryRepositoryError.invalidText(item.id) }
            guard item.tags.count <= 12 && item.tags.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.utf8.count <= 40 }) else {
                throw LibraryRepositoryError.invalidTags(item.id)
            }
            guard categoryIDs.contains(item.categoryID) else { throw LibraryRepositoryError.invalidCategory(item.categoryID) }
            guard (0...1_000_000).contains(item.useCount) else { throw LibraryRepositoryError.invalidUseCount(item.id) }
            guard ids.insert(item.id).inserted else { throw LibraryRepositoryError.duplicateID(item.id) }
        }
    }

    private func readLibrary(from sourceURL: URL) throws -> HandyLibrary {
        let size = (try fileManager.attributesOfItem(atPath: sourceURL.path)[.size] as? NSNumber)?.intValue ?? 0
        guard size <= 5_000_000 else { throw LibraryRepositoryError.fileTooLarge }
        var library = try JSONDecoder().decode(HandyLibrary.self, from: Data(contentsOf: sourceURL))
        guard (1...HandyLibrary.currentVersion).contains(library.version) else { throw LibraryRepositoryError.unsupportedVersion(library.version) }
        library.version = HandyLibrary.currentVersion
        try validate(library)
        return library
    }

    private func libraryData(_ library: HandyLibrary) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(library)
    }
}
