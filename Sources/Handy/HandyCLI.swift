import AppKit
import Foundation
import HandyCore

@MainActor
enum HandyCLI {
    static func runIfRequested(_ rawArguments: [String]) -> Int32? {
        guard let command = rawArguments.first else { return nil }
        let appArguments = [
            "open", "--open", "--check-window", "--check-keyboard", "--check-focus",
            "--check-snippet-focus", "--check-search-performance"
        ]
        if appArguments.contains(command) { return nil }

        do {
            let arguments = Array(rawArguments.dropFirst())
            switch command {
            case "--version", "version":
                print("Handy Palette \(HandyVersion.current)")
            case "--help", "help":
                print(help)
            case "categories":
                let library = try repository(from: arguments).load()
                for category in library.categories.sorted(by: { $0.order < $1.order }) {
                    print("\(category.id)\t\(category.title)\t\(category.symbol)")
                }
            case "list":
                try list(arguments)
            case "snippets":
                try list(["snippet"] + arguments)
            case "search":
                try search(arguments)
            case "add":
                try add(arguments)
            case "copy":
                try copy(arguments)
            case "favorite":
                try favorite(arguments)
            case "favorites":
                try favorites(arguments)
            case "clipboard":
                try clipboard(arguments)
            default:
                throw CLIError("Unknown command: \(command)\n\n\(help)")
            }
            return 0
        } catch {
            fputs("handy-palette: \(error.localizedDescription)\n", stderr)
            return 1
        }
    }

    private static func list(_ arguments: [String]) throws {
        let options = try Options(arguments)
        let library = try repository(from: arguments).load()
        let categoryQuery = options.positionals.first?.lowercased()
        let categoryIDs = Set(library.categories.filter {
            categoryQuery == nil || $0.id.lowercased() == categoryQuery || $0.title.lowercased() == categoryQuery
        }.map(\.id))
        guard categoryQuery == nil || !categoryIDs.isEmpty else { throw CLIError("No category matches \(categoryQuery ?? "").") }
        for item in library.items where categoryQuery == nil || categoryIDs.contains(item.categoryID) {
            printItem(item)
        }
    }

    private static func search(_ arguments: [String]) throws {
        let options = try Options(arguments)
        let query = options.positionals.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { throw CLIError("Usage: handy-palette search <query>") }
        let library = try repository(from: arguments).load()
        for item in library.matches(query) { printItem(item) }
        if UserDefaults.standard.bool(forKey: "clipboardHistoryEnabled") {
            let history = try clipboardRepository(from: arguments).load()
            for entry in history.matches(query) { print("clipboard\t\(entry.id.uuidString.lowercased())\t\(singleLine(entry.text))") }
        }
    }

    private static func add(_ arguments: [String]) throws {
        let options = try Options(arguments)
        guard let title = options.value("title"), !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CLIError("add requires --title <title>.")
        }
        guard let text = options.value("text"), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CLIError("add requires --text <text>.")
        }
        let repo = repository(from: arguments)
        let library = try repo.load()
        let categoryID = options.value("category") ?? library.categories.first(where: { $0.capabilities.contains("custom-entry") })?.id
        guard let categoryID,
              library.categories.contains(where: { $0.id == categoryID && $0.capabilities.contains("custom-entry") }) else {
            throw CLIError("No writable category is available. Pass --category <id>.")
        }
        let tags = options.value("tags")?.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty } ?? []
        let item = HandyItem(
            id: "custom-\(UUID().uuidString.lowercased())",
            text: text,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: Array(tags.prefix(12)),
            categoryID: categoryID,
            isPinned: options.flags.contains("favorite")
        )
        _ = try repo.update { $0.items.append(item) }
        print(item.id)
    }

    private static func copy(_ arguments: [String]) throws {
        let options = try Options(arguments)
        let repo = repository(from: arguments)
        let library = try repo.load()
        let item: HandyItem?
        if let id = options.value("id") {
            item = library.items.first { $0.id == id }
        } else {
            let query = options.positionals.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else {
                throw CLIError("Usage: handy-palette copy <query> or handy-palette copy --id <item-id>")
            }
            item = library.matches(query).first
        }
        guard let item else { throw CLIError("No library item matched.") }
        guard Clipboard.copy(item.text) else { throw CLIError("The system clipboard could not be updated.") }
        _ = try repo.update { $0.recordUse(of: item.id) }
        print(item.text)
    }

    private static func favorite(_ arguments: [String]) throws {
        let options = try Options(arguments)
        let action: String
        let target: String
        if options.positionals.count == 1 {
            action = "toggle"
            target = options.positionals[0]
        } else if options.positionals.count == 2 {
            action = options.positionals[0]
            target = options.positionals[1]
        } else {
            throw CLIError("Usage: handy-palette favorite <add|remove|toggle> <item-id>")
        }
        guard ["add", "remove", "toggle"].contains(action) else {
            throw CLIError("Unknown favorite action: \(action)")
        }
        let repo = repository(from: arguments)
        var matched = false
        var isPinned = false
        _ = try repo.update { library in
            guard let index = library.items.firstIndex(where: { $0.id == target }) else { return }
            matched = true
            switch action {
            case "add": library.items[index].isPinned = true
            case "remove": library.items[index].isPinned = false
            default: library.items[index].isPinned.toggle()
            }
            isPinned = library.items[index].isPinned
        }
        guard matched else { throw CLIError("No item has id \(target).") }
        print(isPinned ? "favorited" : "unfavorited")
    }

    private static func favorites(_ arguments: [String]) throws {
        let options = try Options(arguments)
        guard options.positionals.isEmpty || options.positionals == ["list"] else {
            throw CLIError("Usage: handy-palette favorites [list]")
        }
        for item in try repository(from: arguments).load().items where item.isPinned { printItem(item) }
    }

    private static func clipboard(_ arguments: [String]) throws {
        let options = try Options(arguments)
        guard let action = options.positionals.first else { throw CLIError("Usage: handy-palette clipboard <status|enable|disable|list|clear>") }
        switch action {
        case "status":
            print(UserDefaults.standard.bool(forKey: "clipboardHistoryEnabled") ? "enabled" : "disabled")
        case "enable":
            UserDefaults.standard.set(true, forKey: "clipboardHistoryEnabled")
            print("enabled")
        case "disable":
            UserDefaults.standard.set(false, forKey: "clipboardHistoryEnabled")
            print("disabled")
        case "list":
            for entry in try clipboardRepository(from: arguments).load().entries {
                print("\(entry.id.uuidString.lowercased())\t\(singleLine(entry.text))")
            }
        case "clear":
            try clipboardRepository(from: arguments).save(ClipboardHistory())
            print("cleared")
        default:
            throw CLIError("Unknown clipboard action: \(action)")
        }
    }

    private static func repository(from arguments: [String]) -> LibraryRepository {
        guard let path = optionValue("library", in: arguments) else { return LibraryRepository() }
        return LibraryRepository(url: URL(fileURLWithPath: path))
    }

    private static func clipboardRepository(from arguments: [String]) -> ClipboardHistoryRepository {
        guard let path = optionValue("clipboard-file", in: arguments) else { return ClipboardHistoryRepository() }
        return ClipboardHistoryRepository(url: URL(fileURLWithPath: path))
    }

    private static func optionValue(_ name: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: "--\(name)"), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func printItem(_ item: HandyItem) {
        print("\(item.categoryID)\t\(item.id)\t\(singleLine(item.text))\t\(item.title)")
    }

    private static func singleLine(_ value: String) -> String {
        value.replacingOccurrences(of: "\n", with: "\\n")
    }

    private static let help = """
    Handy Palette \(HandyVersion.current)

    Usage:
      handy-palette open
      handy-palette search <query> [--library <path>]
      handy-palette list [category] [--library <path>]
      handy-palette snippets [--library <path>]
      handy-palette categories [--library <path>]
      handy-palette add --title <title> --text <text> [--tags a,b] [--favorite] [--category <id>]
      handy-palette copy <query> | copy --id <item-id>
      handy-palette favorite <add|remove|toggle> <item-id>
      handy-palette favorites [list]
      handy-palette clipboard <status|enable|disable|list|clear>
      handy-palette version
    """

    private struct Options {
        let values: [String: String]
        let flags: Set<String>
        let positionals: [String]

        init(_ arguments: [String]) throws {
            let valueOptions: Set<String> = ["title", "text", "tags", "category", "id", "library", "clipboard-file"]
            var values: [String: String] = [:]
            var flags: Set<String> = []
            var positionals: [String] = []
            var index = 0
            while index < arguments.count {
                let argument = arguments[index]
                guard argument.hasPrefix("--") else {
                    positionals.append(argument)
                    index += 1
                    continue
                }
                let name = String(argument.dropFirst(2))
                if valueOptions.contains(name) {
                    guard arguments.indices.contains(index + 1), !arguments[index + 1].hasPrefix("--") else {
                        throw CLIError("--\(name) requires a value.")
                    }
                    values[name] = arguments[index + 1]
                    index += 2
                } else {
                    flags.insert(name)
                    index += 1
                }
            }
            self.values = values
            self.flags = flags
            self.positionals = positionals
        }

        func value(_ name: String) -> String? { values[name] }
    }

    private struct CLIError: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }
}
