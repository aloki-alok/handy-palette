import Foundation
import HandyCore

@main
struct HandyChecks {
    static func main() {
        var failures: [String] = []
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            if !condition() { failures.append(message) }
        }

        let library = HandyLibrary.starter
        let happy = library.matches("happy")
        check(happy.first?.id == "happy", "Exact title should rank first")
        check(!happy.contains(where: { $0.id == "shrug" }), "Unmatched entries should be excluded")
        check(library.matches("confused").first?.id == "shrug", "Tags should be searchable")

        let duplicate = HandyLibrary(version: 1, items: [
            HandyItem(id: "same", text: "one", title: "One", tags: [], isPinned: false),
            HandyItem(id: "same", text: "two", title: "Two", tags: [], isPinned: false)
        ])

        let testDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("handy-checks-\(UUID().uuidString)", isDirectory: true)
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
            let oversized = HandyLibrary(version: 1, items: [HandyItem(id: "big", text: oversizedText, title: "Big", tags: [], isPinned: false)])
            do {
                try repository.save(oversized)
                failures.append("Oversized text must be rejected")
            } catch LibraryRepositoryError.invalidText {
                let storedInvalidData = try Data(contentsOf: url)
                check(storedInvalidData == invalidData, "Rejected input must not overwrite existing data")
            }
        } catch {
            failures.append("Library persistence failed: \(error.localizedDescription)")
        }

        if failures.isEmpty {
            print("Handy checks passed: search, UTF-8 JSON persistence, and ranking.")
        } else {
            failures.forEach { FileHandle.standardError.write(Data("FAIL: \($0)\\n".utf8)) }
            exit(1)
        }
    }
}
