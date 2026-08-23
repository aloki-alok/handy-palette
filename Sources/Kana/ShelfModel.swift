import Foundation
import KanaCore

enum SystemShelf: String {
    case recents, favorites, clipboard
}

struct ShelfSection: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let displayGlyph: String?
    let systemShelf: SystemShelf?
    let categoryID: String?

    static func system(_ shelf: SystemShelf, title: String, symbol: String) -> ShelfSection {
        ShelfSection(id: "system:\(shelf.rawValue)", title: title, symbol: symbol, displayGlyph: nil, systemShelf: shelf, categoryID: nil)
    }

    init(category: KanaCategory) {
        id = "category:\(category.id)"
        title = category.title
        symbol = category.symbol
        displayGlyph = category.displayGlyph
        systemShelf = nil
        categoryID = category.id
    }

    private init(id: String, title: String, symbol: String, displayGlyph: String?, systemShelf: SystemShelf?, categoryID: String?) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.displayGlyph = displayGlyph
        self.systemShelf = systemShelf
        self.categoryID = categoryID
    }
}

struct ShelfResult: Identifiable, Equatable {
    let id: String
    let text: String
    let title: String
    let detail: String
    let groupID: String
    let groupTitle: String
    let libraryID: String?
    let isFavorite: Bool

    init(item: KanaItem, category: KanaCategory?) {
        id = "library:\(item.id)"
        text = item.text
        title = item.title
        detail = item.tags.joined(separator: " · ")
        groupID = item.categoryID
        groupTitle = category?.title ?? item.categoryID.capitalized
        libraryID = item.id
        isFavorite = item.isPinned
    }

    init(entry: ClipboardEntry) {
        id = "clipboard:\(entry.id.uuidString)"
        text = entry.text
        title = entry.text.replacingOccurrences(of: "\n", with: " ")
        detail = "clipboard"
        groupID = "clipboard"
        groupTitle = "Clipboard"
        libraryID = nil
        isFavorite = false
    }
}
