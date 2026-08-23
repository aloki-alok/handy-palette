import AppKit
import Foundation
import KanaCore
import KanaShared

@MainActor
enum KanaCLI {
    static func run(_ rawArguments: [String]) -> Int32 {
        do {
            guard let command = rawArguments.first else {
                print(help)
                return 0
            }
            let arguments = Array(rawArguments.dropFirst())
            switch command {
            case "open":
                try openApplication()
            case "--version", "version":
                print("Kana \(KanaVersion.current)")
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
            fputs("kana: \(error.localizedDescription)\n", stderr)
            return 1
        }
    }

    private static func openApplication() throws {
        let executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        let appURL = executableURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        guard appURL.pathExtension == "app" else {
            throw CLIError("The open command is available from the Kana.app helper.")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [appURL.path, "--args", "open"]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CLIError("Kana could not be opened.")
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
        guard !query.isEmpty else { throw CLIError("Usage: kana search <query>") }
        let library = try repository(from: arguments).load()
        for item in library.matches(query) { printItem(item) }
        if KanaPreferences.clipboardHistoryEnabled {
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
        let item = KanaItem(
            id: "custom-\(UUID().uuidString.lowercased())",
            text: text,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: Array(tags.prefix(12)),
            categoryID: categoryID,
            isPinned: options.flags.contains("favorite"),
            pinnedAt: options.flags.contains("favorite") ? .now : nil
        )
        _ = try repo.update { $0.items.append(item) }
        print(item.id)
    }

    private static func copy(_ arguments: [String]) throws {
        let options = try Options(arguments)
        let repo = repository(from: arguments)
        let library = try repo.load()
        let item: KanaItem?
        if let id = options.value("id") {
            item = library.items.first { $0.id == id }
        } else {
            let query = options.positionals.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else {
                throw CLIError("Usage: kana copy <query> or kana copy --id <item-id>")
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
            throw CLIError("Usage: kana favorite <add|remove|toggle> <item-id>")
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
            case "add": library.items[index].setPinned(true)
            case "remove": library.items[index].setPinned(false)
            default: library.items[index].setPinned(!library.items[index].isPinned)
            }
            isPinned = library.items[index].isPinned
        }
        guard matched else { throw CLIError("No item has id \(target).") }
        print(isPinned ? "favorited" : "unfavorited")
    }

    private static func favorites(_ arguments: [String]) throws {
        let options = try Options(arguments)
        guard options.positionals.isEmpty || options.positionals == ["list"] else {
            throw CLIError("Usage: kana favorites [list]")
        }
        for item in try repository(from: arguments).load().favoriteItems() { printItem(item) }
    }

    private static func clipboard(_ arguments: [String]) throws {
        let options = try Options(arguments)
        guard let action = options.positionals.first else { throw CLIError("Usage: kana clipboard <status|enable|disable|list|clear>") }
        switch action {
        case "status":
            print(KanaPreferences.clipboardHistoryEnabled ? "enabled" : "disabled")
        case "enable":
            KanaPreferences.clipboardHistoryEnabled = true
            print("enabled")
        case "disable":
            KanaPreferences.clipboardHistoryEnabled = false
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

    private static func printItem(_ item: KanaItem) {
        print("\(item.categoryID)\t\(item.id)\t\(singleLine(item.text))\t\(item.title)")
    }

    private static func singleLine(_ value: String) -> String {
        value.replacingOccurrences(of: "\n", with: "\\n")
    }

    private static let help = """
    Kana \(KanaVersion.current)

    Usage:
      kana open
      kana search <query> [--library <path>]
      kana list [category] [--library <path>]
      kana snippets [--library <path>]
      kana categories [--library <path>]
      kana add --title <title> --text <text> [--tags a,b] [--favorite] [--category <id>]
      kana copy <query> | copy --id <item-id>
      kana favorite <add|remove|toggle> <item-id>
      kana favorites [list]
      kana clipboard <status|enable|disable|list|clear>
      kana version
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

@main
struct KanaCLIExecutable {
    static func main() {
        exit(KanaCLI.run(Array(CommandLine.arguments.dropFirst())))
    }
}
