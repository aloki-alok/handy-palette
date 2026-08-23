import Foundation
import KanaCore
import KanaShared

@main
struct KanaChecks {
    static func main() {
        var failures: [String] = []
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            if !condition() { failures.append(message) }
        }

        let library = KanaLibrary.starter
        check(checkPreferenceMigration(expectedLegacyValue: true), "Clipboard preference migration should preserve true")
        check(checkPreferenceMigration(expectedLegacyValue: false), "Clipboard preference migration should preserve false")
        check(checkPreferenceMigration(expectedLegacyValue: nil), "Clipboard preference migration should preserve an absent value as false")
        let catalogDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kana-catalog-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: catalogDirectory) }
        do {
            try FileManager.default.createDirectory(at: catalogDirectory, withIntermediateDirectories: true)
            let appCatalog = catalogDirectory.appendingPathComponent("starter-library.json")
            try Data("{\"version\":2,\"catalogRevision\":0,\"categories\":[],\"items\":[]}".utf8).write(to: appCatalog)
            check(
                KanaResources.starterCatalogURL(appResourceURL: catalogDirectory)?.standardizedFileURL == appCatalog.standardizedFileURL,
                "App Resources should take precedence for the starter catalog"
            )
        } catch {
            failures.append("Starter catalog resource lookup failed: \(error.localizedDescription)")
        }
        let happy = library.matches("happy")
        check(happy.first?.id == "happy", "Exact title should rank first")
        check(!happy.contains(where: { $0.id == "shrug" }), "Unmatched entries should be excluded")
        check(library.matches("confused").contains(where: { $0.id == "shrug" }), "Tags should be searchable")
        check(library.matches("emoji").contains(where: { $0.id == "sparkles" }), "Kinds should be searchable")
        check(library.matches("a", limit: 250).count <= 250, "UI search should honor its result limit")
        check(library.categories.first(where: { $0.id == "kaomoji" })?.displayGlyph == ";)", "Category glyphs should come from catalog data")

        var recentlyUsed = library
        recentlyUsed.recordUse(of: "happy", at: Date(timeIntervalSince1970: 10))
        recentlyUsed.recordUse(of: "wave", at: Date(timeIntervalSince1970: 20))
        check(recentlyUsed.recentItems().map(\.id) == ["wave", "happy"], "Recents should sort by latest use")
        var favorites = library
        let waveWasPinned = favorites.items.first(where: { $0.id == "wave" })?.isPinned ?? false
        check(favorites.togglePinned(id: "wave") == !waveWasPinned, "Favorites should toggle by item id")
        var ordered = library
        ordered.items.indices.forEach { ordered.items[$0].setPinned(false) }
        _ = ordered.togglePinned(id: "sparkles", at: Date(timeIntervalSince1970: 10))
        _ = ordered.togglePinned(id: "shrug", at: Date(timeIntervalSince1970: 20))
        _ = ordered.togglePinned(id: "happy", at: Date(timeIntervalSince1970: 30))
        check(ordered.favoriteItems().map(\.id) == ["happy", "shrug", "sparkles"], "Favorites should list the newest star first")
        _ = ordered.togglePinned(id: "shrug", at: Date(timeIntervalSince1970: 40))
        check(ordered.items.first(where: { $0.id == "shrug" })?.pinnedAt == nil, "Unstarring should clear the favorite timestamp")
        _ = ordered.togglePinned(id: "shrug", at: Date(timeIntervalSince1970: 50))
        check(ordered.favoriteItems().map(\.id) == ["shrug", "happy", "sparkles"], "Re-starring should move an item back to the top")
        let legacy = KanaLibrary(version: KanaLibrary.currentVersion, categories: library.categories, items: [
            KanaItem(id: "carried-over", text: "(-_-)", title: "Carried over", tags: [], categoryID: "kaomoji", isPinned: true),
            KanaItem(id: "stamped", text: "(o_o)", title: "Stamped", tags: [], categoryID: "kaomoji", isPinned: true, pinnedAt: Date(timeIntervalSince1970: 60))
        ])
        check(legacy.favoriteItems().map(\.id) == ["stamped", "carried-over"], "A stamped favorite should outrank one carried over without a timestamp")

        let sandbox = FileManager.default.temporaryDirectory.appendingPathComponent("kana-migration-\(UUID().uuidString)", isDirectory: true)
        let legacyFolder = sandbox.appendingPathComponent("Handy", isDirectory: true)
        try? FileManager.default.createDirectory(at: legacyFolder, withIntermediateDirectories: true)
        try? Data("{}".utf8).write(to: legacyFolder.appendingPathComponent("library.json"))
        let adopted = KanaSupportFolder.folder(root: sandbox)
        check(adopted.lastPathComponent == "Kana", "A pre-rename support folder should be adopted as Kana")
        check(FileManager.default.fileExists(atPath: adopted.appendingPathComponent("library.json").path), "The adopted folder should still hold the library")
        check(!FileManager.default.fileExists(atPath: legacyFolder.path), "The legacy folder should be gone after adoption")
        let secondRun = KanaSupportFolder.folder(root: sandbox)
        check(secondRun == adopted, "Adoption should be idempotent")
        try? FileManager.default.removeItem(at: sandbox)

        // Homebrew installs the command as a symlink, so a lookup relative to the symlink
        // finds nothing. Every shipped layout has to resolve without the build directory.
        let helpers = URL(fileURLWithPath: "/Apps/Kana.app/Contents/Helpers/kana")
        let helperCandidates = KanaResources.candidates(appResourceURL: nil, executableURL: helpers).map(\.path)
        check(helperCandidates.contains("/Apps/Kana.app/Contents/Resources/starter-library.json"),
              "A helper beside an app bundle should look in the bundle's Resources")
        check(helperCandidates.contains("/Apps/Kana.app/Contents/Resources/Kana_KanaCore.bundle/starter-library.json"),
              "A helper beside an app bundle should look inside the copied resource bundle")
        check(helperCandidates.contains("/Apps/Kana.app/Contents/Helpers/starter-library.json"),
              "A helper should also look beside itself")

        var clipboardHistory = ClipboardHistory()
        check(clipboardHistory.capture("first", at: Date(timeIntervalSince1970: 1)), "Clipboard should accept valid text")
        check(!clipboardHistory.capture("first", at: Date(timeIntervalSince1970: 2)), "Clipboard should reject adjacent duplicates")
        check(!clipboardHistory.capture("   "), "Clipboard should reject blank text")
        check(clipboardHistory.capture("second", at: Date(timeIntervalSince1970: 3)), "Clipboard should accept a different value")
        check(clipboardHistory.matches("fir").first?.text == "first", "Clipboard history should be searchable")
        check(!ClipboardHistory.allowsCapture(pasteboardTypeNames: ["org.nspasteboard.ConcealedType"]), "Concealed pasteboard values must be ignored")
        check(ClipboardHistory.allowsCapture(pasteboardTypeNames: ["public.utf8-plain-text"]), "Ordinary text pasteboard values should be accepted")

        check(PaletteKeyboardRouter.command(keyCode: 125, characters: nil, modifiers: []) == .moveSelection(1), "Down Arrow should move to the next result")
        check(PaletteKeyboardRouter.command(keyCode: 126, characters: nil, modifiers: []) == .moveSelection(-1), "Up Arrow should move to the previous result")
        check(PaletteKeyboardRouter.command(keyCode: 36, characters: nil, modifiers: []) == .activateSelection, "Return should activate the selection")
        check(PaletteKeyboardRouter.command(keyCode: 76, characters: nil, modifiers: []) == .activateSelection, "Keypad Enter should activate the selection")
        check(PaletteKeyboardRouter.command(keyCode: 53, characters: nil, modifiers: []) == .dismiss, "Escape should dismiss the palette")
        check(PaletteKeyboardRouter.command(keyCode: 48, characters: nil, modifiers: [.control]) == .cycleSection(1), "Control-Tab should cycle sections")
        check(PaletteKeyboardRouter.command(keyCode: 48, characters: nil, modifiers: [.control, .shift]) == .cycleSection(-1), "Control-Shift-Tab should reverse sections")
        check(PaletteKeyboardRouter.command(keyCode: 48, characters: nil, modifiers: [.control, .option]) == nil, "Control-Option-Tab should remain available to the system")
        check(PaletteKeyboardRouter.command(keyCode: 18, characters: "1", modifiers: [.command]) == .selectSection(0), "Command-1 should select the first section")
        check(PaletteKeyboardRouter.command(keyCode: 45, characters: "n", modifiers: [.command]) == .newCustomItem, "Command-N should open the custom item editor")
        check(PaletteKeyboardRouter.command(keyCode: 2, characters: "d", modifiers: [.command]) == .toggleFavorite, "Command-D should toggle a favorite")
        let numberKeyCodes: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28, 25]
        for (index, keyCode) in numberKeyCodes.enumerated() {
            check(PaletteKeyboardRouter.command(keyCode: keyCode, characters: nil, modifiers: [.command]) == .selectSection(index), "Command-number key code \(keyCode) should select section \(index + 1)")
        }
        check(PaletteKeyboardRouter.command(keyCode: 123, characters: nil, modifiers: []) == nil, "Left Arrow should remain a text-editing key")
        check(PaletteKeyboardRouter.command(keyCode: 125, characters: nil, modifiers: [.option]) == nil, "Option-Arrow should remain a text-editing key")

        let duplicate = KanaLibrary(version: KanaLibrary.currentVersion, items: [
            KanaItem(id: "same", text: "one", title: "One", tags: [], isPinned: false),
            KanaItem(id: "same", text: "two", title: "Two", tags: [], isPinned: false)
        ])

        let testDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kana-checks-\(UUID().uuidString)", isDirectory: true)
        let url = testDirectory.appendingPathComponent("library.json")
        defer { try? FileManager.default.removeItem(at: testDirectory) }
        let repository = LibraryRepository(url: url)
        do {
            var changed = library
            changed.items[0].useCount = 7
            try repository.save(changed)
            let reloaded = try repository.load()
            check(reloaded == changed, "Library must round-trip without Unicode loss")
            let data = try Data(contentsOf: url)
            let rawJSON = String(decoding: data, as: UTF8.self)
            check(rawJSON.contains("ツ") && rawJSON.contains("¯"), "Kaomoji should remain valid UTF-8 JSON")

            let coordinatedURL = testDirectory.appendingPathComponent("coordinated.json")
            let coordinatedRepository = LibraryRepository(url: coordinatedURL)
            try coordinatedRepository.save(library)
            _ = try coordinatedRepository.update { updated in
                _ = updated.togglePinned(id: "wave")
            }
            let customItem = KanaItem(
                id: "custom-check",
                text: "Saved snippet",
                title: "Saved snippet",
                tags: ["qa"],
                categoryID: "snippet",
                isPinned: false
            )
            _ = try coordinatedRepository.update { $0.items.append(customItem) }
            let coordinated = try coordinatedRepository.load()
            check(coordinated.items.first(where: { $0.id == "wave" })?.isPinned == true, "A later update must preserve an earlier favorite change")
            check(coordinated.items.contains(where: { $0.id == "custom-check" }), "Custom snippets must persist across coordinated updates")

            let legacyURL = testDirectory.appendingPathComponent("legacy.json")
            let legacyJSON = """
            {"version":1,"items":[{"id":"legacy","text":"✨","title":"Legacy","tags":["emoji"],"isPinned":false,"useCount":0}]}
            """
            try Data(legacyJSON.utf8).write(to: legacyURL, options: .atomic)
            let migrated = try LibraryRepository(url: legacyURL).load()
            check(migrated.version == KanaLibrary.currentVersion, "Version 1 libraries should migrate in memory")
            check(migrated.items.first(where: { $0.id == "legacy" })?.categoryID == "emoji", "Legacy tags should infer the item category")
            check(migrated.items.count == library.items.count + 1, "Legacy libraries should receive the current catalog without losing custom items")

            do {
                try repository.save(duplicate)
                failures.append("Duplicate IDs must be rejected")
            } catch LibraryRepositoryError.duplicateID {
                let stillValid = try repository.load()
                check(stillValid == changed, "Invalid save must not replace a valid library")
            }

            let invalidData = Data("{\"version\":1,\"items\":[{\"id\":\"x\",\"text\":\"a\",\"title\":\"One\",\"tags\":[],\"isPinned\":false,\"useCount\":0},{\"id\":\"x\",\"text\":\"b\",\"title\":\"Two\",\"tags\":[],\"isPinned\":false,\"useCount\":0}]}".utf8)
            try invalidData.write(to: url, options: .atomic)
            do {
                _ = try repository.load()
                failures.append("Invalid on-disk libraries must be rejected")
            } catch LibraryRepositoryError.duplicateID {
                let storedInvalidData = try Data(contentsOf: url)
                check(storedInvalidData == invalidData, "Invalid on-disk libraries must never be overwritten during recovery")
            }

            let oversizedText = String(repeating: "x", count: 10_001)
            let oversized = KanaLibrary(version: KanaLibrary.currentVersion, items: [KanaItem(id: "big", text: oversizedText, title: "Big", tags: [], isPinned: false)])
            do {
                try repository.save(oversized)
                failures.append("Oversized text must be rejected")
            } catch LibraryRepositoryError.invalidText {
                let storedInvalidData = try Data(contentsOf: url)
                check(storedInvalidData == invalidData, "Rejected input must not overwrite existing data")
            }

            let clipboardURL = testDirectory.appendingPathComponent("clipboard.json")
            let clipboardRepository = ClipboardHistoryRepository(url: clipboardURL)
            var persistedClipboard = ClipboardHistory()
            _ = persistedClipboard.capture("safe")
            try clipboardRepository.save(persistedClipboard)
            _ = try clipboardRepository.update { _ = $0.capture("second") }
            _ = try clipboardRepository.update { _ = $0.capture("third") }
            let coordinatedClipboardTexts = try clipboardRepository.load().entries.map(\.text)
            check(Array(coordinatedClipboardTexts.prefix(3)) == ["third", "second", "safe"], "Coordinated clipboard updates must preserve earlier entries")

            let legacyClipboardJSON = """
            {"version":1,"entries":[{"id":"00000000-0000-0000-0000-000000000001","text":"legacy","capturedAt":0,"sourceBundleID":"com.example.private"}]}
            """
            try Data(legacyClipboardJSON.utf8).write(to: clipboardURL, options: .atomic)
            let migratedClipboard = try clipboardRepository.load()
            try clipboardRepository.save(migratedClipboard)
            let sanitizedClipboardJSON = String(decoding: try Data(contentsOf: clipboardURL), as: UTF8.self)
            check(!sanitizedClipboardJSON.contains("sourceBundleID"), "Legacy source application metadata must be removed on save")

            let oversizedClipboardJSON = "{\"version\":1,\"entries\":[{\"id\":\"00000000-0000-0000-0000-000000000001\",\"text\":\"\(String(repeating: "x", count: ClipboardHistory.maximumTextBytes + 1))\",\"capturedAt\":0}]}"
            let invalidClipboardData = Data(oversizedClipboardJSON.utf8)
            try invalidClipboardData.write(to: clipboardURL, options: .atomic)
            do {
                _ = try clipboardRepository.load()
                failures.append("Oversized clipboard entries must be rejected")
            } catch {
                let storedClipboardData = try Data(contentsOf: clipboardURL)
                check(storedClipboardData == invalidClipboardData, "Invalid clipboard input must remain untouched for recovery")
            }
        } catch {
            failures.append("Library persistence failed: \(error.localizedDescription)")
        }

        if failures.isEmpty {
            print("Kana checks passed: search, persistence, favorites, snippets, clipboard, and keyboard routing.")
        } else {
            failures.forEach { FileHandle.standardError.write(Data("FAIL: \($0)\\n".utf8)) }
            exit(1)
        }
    }

    private static func checkPreferenceMigration(expectedLegacyValue: Bool?) -> Bool {
        let identifier = UUID().uuidString
        let suiteName = "io.github.aloki-alok.kana.tests.\(identifier)"
        let legacyDomainName = "KanaTests.\(identifier)"
        defer {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
            UserDefaults.standard.removePersistentDomain(forName: legacyDomainName)
        }
        if let expectedLegacyValue {
            UserDefaults.standard.setPersistentDomain(
                [KanaPreferences.clipboardHistoryEnabledKey: expectedLegacyValue],
                forName: legacyDomainName
            )
        }
        let preferences = KanaPreferencesStore(
            suiteName: suiteName,
            legacyDomainNames: [legacyDomainName]
        )
        let migratedValue = preferences.clipboardHistoryEnabled
        if let expectedLegacyValue {
            UserDefaults.standard.setPersistentDomain(
                [KanaPreferences.clipboardHistoryEnabledKey: !expectedLegacyValue],
                forName: legacyDomainName
            )
        }
        return migratedValue == (expectedLegacyValue ?? false)
            && preferences.clipboardHistoryEnabled == migratedValue
    }
}
