import Foundation
import Observation
import HandyCore
import AppKit

@MainActor @Observable
final class LibraryStore {
    private let repository: LibraryRepository
    private let clipboardRepository: ClipboardHistoryRepository
    private(set) var library: HandyLibrary
    private(set) var clipboardHistory: ClipboardHistory
    private(set) var isClipboardHistoryEnabled = UserDefaults.standard.bool(forKey: "clipboardHistoryEnabled")
    var errorMessage: String?
    private var clipboardWatcher: ClipboardWatcher?
    @ObservationIgnored private var cachedSearchQuery: String?
    @ObservationIgnored private var cachedSearchResults: [ShelfResult] = []

    private static let clipboardEnabledKey = "clipboardHistoryEnabled"

    init(repository: LibraryRepository = LibraryRepository(), clipboardRepository: ClipboardHistoryRepository = ClipboardHistoryRepository()) {
        self.repository = repository
        self.clipboardRepository = clipboardRepository
        do {
            self.library = try repository.load()
        } catch {
            self.library = .starter
            self.errorMessage = error.localizedDescription
        }
        do { self.clipboardHistory = try clipboardRepository.load() }
        catch {
            self.clipboardHistory = ClipboardHistory()
            self.errorMessage = error.localizedDescription
        }
        clipboardWatcher = ClipboardWatcher { [weak self] text, sourceBundleID in
            self?.captureClipboard(text, sourceBundleID: sourceBundleID)
        }
        if isClipboardHistoryEnabled { clipboardWatcher?.start() }
    }

    var libraryPath: String { repository.url.path }
    var itemCount: Int { library.items.count }
    var customEntryCategory: HandyCategory? {
        library.categories.first { $0.capabilities.contains("custom-entry") }
    }

    var sections: [ShelfSection] {
        [
            .system(.recents, title: "Recents", symbol: "clock"),
            .system(.favorites, title: "Favorites", symbol: "star"),
            .system(.clipboard, title: "Clipboard", symbol: "clipboard")
        ] + library.categories.sorted { $0.order < $1.order }.map(ShelfSection.init)
    }

    var searchGroupOrder: [String] {
        ["clipboard"] + library.categories.sorted { $0.order < $1.order }.map(\.id)
    }

    func results(in section: ShelfSection) -> [ShelfResult] {
        if let systemShelf = section.systemShelf {
            switch systemShelf {
            case .recents: return library.recentItems().map(makeResult)
            case .favorites: return library.items.filter(\.isPinned).map(makeResult)
            case .clipboard: return clipboardHistory.entries.map(ShelfResult.init)
            }
        }
        guard let categoryID = section.categoryID else { return [] }
        return library.items.filter { $0.categoryID == categoryID }.map(makeResult)
    }

    func search(_ query: String) -> [ShelfResult] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if cachedSearchQuery == normalized { return cachedSearchResults }
        cachedSearchQuery = normalized
        cachedSearchResults = clipboardHistory.matches(query).map(ShelfResult.init)
            + library.matches(query, limit: 250).map(makeResult)
        return cachedSearchResults
    }

    func setClipboardHistoryEnabled(_ enabled: Bool) {
        isClipboardHistoryEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.clipboardEnabledKey)
        enabled ? clipboardWatcher?.start() : clipboardWatcher?.stop()
    }

    func clearClipboardHistory() {
        clipboardHistory = ClipboardHistory()
        invalidateSearchCache()
        do { try clipboardRepository.save(clipboardHistory) }
        catch { errorMessage = "Clipboard history could not be cleared: \(error.localizedDescription)" }
    }

    @discardableResult
    func addCustomItem(text: String, title: String, tags: [String], categoryID: String) -> String? {
        guard library.categories.contains(where: { $0.id == categoryID && $0.capabilities.contains("custom-entry") }) else {
            errorMessage = "That section does not accept custom items."
            return nil
        }
        let item = HandyItem(
            id: "custom-\(UUID().uuidString.lowercased())",
            text: text,
            title: title,
            tags: tags,
            categoryID: categoryID,
            isPinned: false
        )
        do {
            library = try repository.update { $0.items.append(item) }
            invalidateSearchCache()
            return item.id
        } catch {
            errorMessage = "The item could not be saved: \(error.localizedDescription)"
            return nil
        }
    }

    func recordUse(of result: ShelfResult) {
        guard let libraryID = result.libraryID else { return }
        do {
            library = try repository.update { $0.recordUse(of: libraryID) }
            invalidateSearchCache()
        }
        catch { errorMessage = "Copied, but Recents could not be updated: \(error.localizedDescription)" }
    }

    func toggleFavorite(of result: ShelfResult) {
        guard let libraryID = result.libraryID else { return }
        do {
            library = try repository.update { updated in
                _ = updated.togglePinned(id: libraryID)
            }
            invalidateSearchCache()
        }
        catch {
            errorMessage = "The favorite could not be updated: \(error.localizedDescription)"
        }
    }

    func ignoreCurrentClipboardChange() { clipboardWatcher?.ignoreCurrentChange() }

    func reportCopyFailure() { errorMessage = "Handy could not write to the system clipboard. Nothing was copied." }

    func openLibraryInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([repository.url])
    }

    private func captureClipboard(_ text: String, sourceBundleID: String?) {
        guard clipboardHistory.capture(text, sourceBundleID: sourceBundleID) else { return }
        invalidateSearchCache()
        do { try clipboardRepository.save(clipboardHistory) }
        catch { errorMessage = "Clipboard history could not be saved: \(error.localizedDescription)" }
    }

    private func makeResult(_ item: HandyItem) -> ShelfResult {
        ShelfResult(item: item, category: library.categories.first { $0.id == item.categoryID })
    }

    private func invalidateSearchCache() {
        cachedSearchQuery = nil
        cachedSearchResults = []
    }

}
