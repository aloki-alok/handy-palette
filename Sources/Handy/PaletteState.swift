import Observation

@MainActor @Observable
final class PaletteState {
    var query = ""
    var selectedSectionID = "system:recents"
    var selection: Int?
    var newItemRequest = 0

    func reset() {
        query = ""
        selectedSectionID = "system:recents"
        selection = nil
    }

    func selectSection(at index: Int, sections: [ShelfSection]) {
        guard sections.indices.contains(index) else { return }
        selectedSectionID = sections[index].id
        query = ""
        selection = nil
    }

    func cycleSection(by offset: Int, sections: [ShelfSection]) {
        guard !sections.isEmpty,
              let current = sections.firstIndex(where: { $0.id == selectedSectionID }) else { return }
        let next = (current + offset + sections.count) % sections.count
        selectSection(at: next, sections: sections)
    }

    func moveSelection(by offset: Int, resultCount: Int) {
        guard resultCount > 0 else { return }
        guard let selection else {
            self.selection = offset < 0 ? resultCount - 1 : 0
            return
        }
        self.selection = min(max(0, selection + offset), resultCount - 1)
    }
}
