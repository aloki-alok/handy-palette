import Foundation
import Observation
import HandyCore
import AppKit

@MainActor @Observable
final class LibraryStore {
    private let repository: LibraryRepository
    private(set) var library: HandyLibrary
    var errorMessage: String?

    init(repository: LibraryRepository = LibraryRepository()) {
        self.repository = repository
        do {
            self.library = try repository.load()
        } catch {
            self.library = .starter
            self.errorMessage = error.localizedDescription
        }
    }

    var libraryPath: String { repository.url.path }

    func items(matching query: String) -> [HandyItem] { library.matches(query) }

    func reportCopyFailure() { errorMessage = "Handy could not write to the system clipboard. Nothing was copied." }

    func openLibraryInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([repository.url])
    }

}
