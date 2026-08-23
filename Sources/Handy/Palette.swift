import AppKit
import SwiftUI
import HandyCore
import HandyShared

private final class PalettePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class PaletteController {
    private let store = LibraryStore()
    private let state = PaletteState()
    private var panel: NSPanel?
    private var keyboardMonitor: Any?

    var isClipboardHistoryEnabled: Bool { store.isClipboardHistoryEnabled }
    var diagnosticState: String {
        guard let panel else { return "panel=nil" }
        return "visible=\(panel.isVisible) key=\(panel.isKeyWindow) canKey=\(panel.canBecomeKey) occluded=\(!panel.occlusionState.contains(.visible)) screen=\(panel.screen?.localizedName ?? "none")"
    }

    func runFocusDiagnostic(completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let responder = self.panel?.firstResponder
            let ownsTextInput = responder is NSTextView || responder is NSTextField
            let responderName = responder.map { String(describing: type(of: $0)) } ?? "nil"
            self.postKeyEvent(keyCode: 0, characters: "focus-probe")
            self.finishFocusDiagnostic(
                responderName: responderName,
                ownsTextInput: ownsTextInput,
                attemptsRemaining: 10,
                completion: completion
            )
        }
    }

    private func finishFocusDiagnostic(
        responderName: String,
        ownsTextInput: Bool,
        attemptsRemaining: Int,
        completion: @escaping (Bool, String) -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let passed = NSApp.isActive
                && self.panel?.isKeyWindow == true
                && ownsTextInput
                && self.state.query == "focus-probe"
            if passed || attemptsRemaining == 1 {
                completion(passed, "active=\(NSApp.isActive) key=\(self.panel?.isKeyWindow == true) responder=\(responderName) input=\(self.state.query == "focus-probe")")
                return
            }
            self.finishFocusDiagnostic(
                responderName: responderName,
                ownsTextInput: ownsTextInput,
                attemptsRemaining: attemptsRemaining - 1,
                completion: completion
            )
        }
    }

    /// The hotkey path: another app owns the foreground when the palette opens.
    func runBackgroundFocusDiagnostic(completion: @escaping (Bool, String) -> Void) {
        hide()
        guard let other = NSWorkspace.shared.runningApplications.first(where: {
            $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }) else {
            completion(false, "no other foreground app to yield to")
            return
        }
        other.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.show()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                let responder = self.panel?.firstResponder
                let responderName = responder.map { String(describing: type(of: $0)) } ?? "nil"
                let ownsTextInput = responder is NSTextView || responder is NSTextField
                self.postKeyEvent(keyCode: 0, characters: "focus-probe")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    let typed = self.state.query == "focus-probe"
                    let passed = self.panel?.isKeyWindow == true && ownsTextInput && typed
                    completion(passed, "yieldedTo=\(other.localizedName ?? "?") key=\(self.panel?.isKeyWindow == true) responder=\(responderName) input=\(typed)")
                }
            }
        }
    }

    func runSnippetFocusDiagnostic(completion: @escaping (Bool, String) -> Void) {
        prepareCustomItemEditor()
        finishSnippetFocusDiagnostic(attemptsRemaining: 20, completion: completion)
    }

    private func finishSnippetFocusDiagnostic(
        attemptsRemaining: Int,
        completion: @escaping (Bool, String) -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let sheet = self.panel?.attachedSheet
            let responder = sheet?.firstResponder
            let ownsTextInput = responder is NSTextView || responder is NSTextField
            let passed = NSApp.isActive && sheet?.isKeyWindow == true && ownsTextInput
            let responderName = responder.map { String(describing: type(of: $0)) } ?? "nil"
            if !passed && attemptsRemaining > 1 {
                self.finishSnippetFocusDiagnostic(
                    attemptsRemaining: attemptsRemaining - 1,
                    completion: completion
                )
                return
            }
            completion(passed, "active=\(NSApp.isActive) sheetKey=\(sheet?.isKeyWindow == true) responder=\(responderName)")
        }
    }

    func runSearchPerformanceDiagnostic(completion: @escaping (Bool, String) -> Void) {
        let startedAt = ContinuousClock.now
        state.query = "a"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let elapsed = ContinuousClock.now - startedAt
            let milliseconds = elapsed.components.seconds * 1_000
                + Int64(elapsed.components.attoseconds / 1_000_000_000_000_000)
            completion(milliseconds < 500, "query=a latency=\(milliseconds)ms results=\(self.visibleResults().count)")
        }
    }

    func toggle() {
        if let panel, panel.isVisible { hide(); return }
        show()
    }

    func show() {
        if let panel, panel.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
            return
        }
        state.reset()
        let view = PaletteView(
            store: store,
            state: state,
            dismiss: { [weak self] in self?.hide() },
            activateSelection: { [weak self] in self?.activateSelection() },
            requestClipboardHistoryToggle: { [weak self] in self?.toggleClipboardHistory() },
            clearClipboardHistory: { [weak self] in self?.clearClipboardHistory() }
        )
        let panel = PalettePanel(
            contentRect: NSRect(origin: .zero, size: CGSize(width: 660, height: 500)),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.center()
        let hostingView = NSHostingView(rootView: view)
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 12
        hostingView.layer?.cornerCurve = .continuous
        hostingView.layer?.masksToBounds = true
        panel.contentView = hostingView
        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        installKeyboardMonitor()
        DispatchQueue.main.async { [weak self, weak panel] in
            guard let self, let panel, self.panel === panel, panel.isVisible else { return }
            panel.makeKeyAndOrderFront(nil)
        }
    }

    func hide() {
        panel?.orderOut(nil)
        if let keyboardMonitor {
            NSEvent.removeMonitor(keyboardMonitor)
            self.keyboardMonitor = nil
        }
    }

    func revealLibrary() { store.openLibraryInFinder() }
    func requestNewCustomItem() {
        if panel?.isVisible != true { show() }
        DispatchQueue.main.async { self.prepareCustomItemEditor() }
    }
    private func prepareCustomItemEditor() {
        guard let category = store.customEntryCategory,
              let index = store.sections.firstIndex(where: { $0.categoryID == category.id }) else { return }
        state.selectSection(at: index, sections: store.sections)
        state.newItemRequest += 1
    }
    func toggleClipboardHistory() {
        if store.isClipboardHistoryEnabled {
            store.setClipboardHistoryEnabled(false)
            return
        }
        let alert = NSAlert()
        alert.messageText = "Enable clipboard history?"
        alert.informativeText = "Handy Palette will save up to 50 text copies made after you enable it. The history stays on this Mac. Items marked as concealed or transient by password managers are ignored, but apps do not always label sensitive text correctly."
        alert.addButton(withTitle: "Enable history")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            store.setClipboardHistoryEnabled(true)
        }
    }

    func clearClipboardHistory() {
        guard !store.clipboardHistory.entries.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = "Clear clipboard history?"
        alert.informativeText = "This permanently removes all text saved in Handy Palette clipboard history."
        alert.addButton(withTitle: "Clear history")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            store.clearClipboardHistory()
        }
    }

    private func visibleResults() -> [ShelfResult] {
        let trimmedQuery = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty { return store.search(state.query) }
        guard let section = store.sections.first(where: { $0.id == state.selectedSectionID }) else { return [] }
        return store.results(in: section)
    }

    private func activateSelection() {
        let results = visibleResults()
        guard let selection = state.selection, results.indices.contains(selection) else { return }
        let result = results[selection]
        guard Clipboard.copy(result.text) else {
            store.reportCopyFailure()
            return
        }
        store.ignoreCurrentClipboardChange()
        store.recordUse(of: result)
        hide()
    }

    private func toggleFavoriteSelection() {
        let results = visibleResults()
        guard let selection = state.selection, results.indices.contains(selection) else { return }
        store.toggleFavorite(of: results[selection])
    }

    func runKeyboardDiagnostic(completion: @escaping (Bool, String) -> Void) {
        guard store.sections.indices.contains(3), store.results(in: store.sections[3]).count > 1 else {
            completion(false, "catalog section unavailable")
            return
        }
        let expectedText = store.results(in: store.sections[3])[0].text
        postKeyEvent(keyCode: 21, characters: "4", modifiers: .command)
        postKeyEvent(keyCode: 125)
        postKeyEvent(keyCode: 36, characters: "\r")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let copiedText = NSPasteboard.general.string(forType: .string)
            let returnPassed = copiedText == expectedText && self.panel?.isVisible == false
            self.show()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.postKeyEvent(keyCode: 53, characters: "\u{1b}")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let escapePassed = self.panel?.isVisible == false
                let detail = "return=\(returnPassed) escape=\(escapePassed) keyCapable=\(self.panel?.canBecomeKey == true)"
                completion(returnPassed && escapePassed, detail)
            }
        }
    }

    private func handleKeyboardCommand(_ command: PaletteKeyboardCommand) {
        switch command {
        case .moveSelection(let offset): state.moveSelection(by: offset, resultCount: visibleResults().count)
        case .activateSelection: activateSelection()
        case .dismiss: hide()
        case .cycleSection(let offset):
            state.cycleSection(by: offset, sections: store.sections)
            state.searchFocusRequest += 1
        case .selectSection(let index):
            state.selectSection(at: index, sections: store.sections)
            state.searchFocusRequest += 1
        case .newCustomItem: prepareCustomItemEditor()
        case .toggleFavorite: toggleFavoriteSelection()
        }
    }

    private func installKeyboardMonitor() {
        if let keyboardMonitor { NSEvent.removeMonitor(keyboardMonitor) }
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let panel = self.panel,
                  panel.isVisible,
                  panel.isKeyWindow,
                  event.windowNumber == panel.windowNumber else {
                return event
            }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            var modifiers: PaletteKeyModifiers = []
            if flags.contains(.command) { modifiers.insert(.command) }
            if flags.contains(.control) { modifiers.insert(.control) }
            if flags.contains(.option) { modifiers.insert(.option) }
            if flags.contains(.shift) { modifiers.insert(.shift) }
            guard let command = PaletteKeyboardRouter.command(keyCode: event.keyCode, characters: event.charactersIgnoringModifiers, modifiers: modifiers) else {
                return event
            }
            self.handleKeyboardCommand(command)
            return nil
        }
    }

    private func postKeyEvent(
        keyCode: UInt16,
        characters: String = "",
        modifiers: NSEvent.ModifierFlags = []
    ) {
        guard let panel,
              let event = NSEvent.keyEvent(
                  with: .keyDown,
                  location: .zero,
                  modifierFlags: modifiers,
                  timestamp: ProcessInfo.processInfo.systemUptime,
                  windowNumber: panel.windowNumber,
                  context: nil,
                  characters: characters,
                  charactersIgnoringModifiers: characters,
                  isARepeat: false,
                  keyCode: keyCode
              ) else { return }
        NSApp.sendEvent(event)
    }

}

struct PaletteView: View {
    @Bindable var store: LibraryStore
    @Bindable var state: PaletteState
    let dismiss: () -> Void
    let activateSelection: () -> Void
    let requestClipboardHistoryToggle: () -> Void
    let clearClipboardHistory: () -> Void
    @State private var hoveredSectionID: String?
    @State private var hoveredResultID: String?
    @State private var isPresentingNewItem = false
    @FocusState private var searchFocused: Bool
    @Namespace private var railSelection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedSection: ShelfSection {
        store.sections.first { $0.id == state.selectedSectionID } ?? store.sections[0]
    }

    private var results: [ShelfResult] {
        state.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? store.results(in: selectedSection)
            : store.search(state.query)
    }

    private var groupedResults: [(String, [ShelfResult])] {
        guard !state.query.isEmpty else { return [(selectedSection.title, results)] }
        var seen: [String] = []
        var groups: [String: [ShelfResult]] = [:]
        for result in results {
            if groups[result.groupID] == nil { seen.append(result.groupID) }
            groups[result.groupID, default: []].append(result)
        }
        return seen.compactMap { id in
            guard let values = groups[id], let title = values.first?.groupTitle else { return nil }
            return (title, values)
        }.sorted { lhs, rhs in
            (store.searchGroupOrder.firstIndex(of: lhs.1[0].groupID) ?? .max) < (store.searchGroupOrder.firstIndex(of: rhs.1[0].groupID) ?? .max)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            Divider()
            HStack(spacing: 0) {
                rail.zIndex(2)
                Divider()
                resultList
            }
        }
        .frame(minWidth: 640, minHeight: 420)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { searchFocused = true }
        .onExitCommand(perform: dismiss)
        .onMoveCommand(perform: moveSelection)
        .onChange(of: state.newItemRequest) { _, _ in
            if store.customEntryCategory != nil { isPresentingNewItem = true }
        }
        .onChange(of: state.searchFocusRequest) { _, _ in searchFocused = true }
        .sheet(isPresented: $isPresentingNewItem) {
            if let category = store.customEntryCategory {
                NewCustomItemSheet(category: category) { title, text, tags in
                    addCustomItem(title: title, text: text, tags: tags, category: category)
                }
            }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "The action could not be completed.")
        }
    }

    private var searchHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search everything", text: $state.query)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .medium))
                .focused($searchFocused)
                .onChange(of: state.query) { _, _ in state.selection = nil }
                .onKeyPress(keys: [.upArrow, .downArrow, .return, .escape, .tab]) { keyPress in
                    handleSearchKey(keyPress)
                }
            if !state.query.isEmpty {
                Button { state.query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
    }

    private var rail: some View {
        ScrollView {
            LazyVStack(spacing: 5) {
                ForEach(Array(store.sections.enumerated()), id: \.element.id) { index, section in
                    sectionButton(section, index: index)
                }
            }
            .padding(8)
        }
        .scrollClipDisabled()
        .frame(width: 58)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.42))
    }

    @ViewBuilder
    private func sectionButton(_ section: ShelfSection, index: Int) -> some View {
        let selected = state.selectedSectionID == section.id && state.query.isEmpty
        Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.84)) {
                selectSection(at: index)
            }
        } label: {
            VStack(spacing: 3) {
                sectionMark(section)
                    .font(.system(size: 15, weight: selected ? .semibold : .regular))
                    .scaleEffect(selected ? 1.06 : hoveredSectionID == section.id ? 1.025 : 1)
                if index < 9 { Text("⌘\(index + 1)").font(.system(size: 8, design: .monospaced)) }
            }
            .frame(width: 40, height: 42)
            .foregroundStyle(selected ? Color.accentColor : Color.secondary)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.accentColor.opacity(0.14))
                        .matchedGeometryEffect(id: "rail-selection", in: railSelection)
                } else if hoveredSectionID == section.id {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.primary.opacity(0.07))
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: hoveredSectionID)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(
            index < 9
                ? KeyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                : nil
        )
        .accessibilityLabel(section.title)
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.14)) {
                hoveredSectionID = hovering ? section.id : nil
            }
        }
        .help(section.title)
    }

    @ViewBuilder
    private func sectionMark(_ section: ShelfSection) -> some View {
        if let glyph = section.displayGlyph {
            Text(glyph)
                .fontDesign(.monospaced)
        } else {
            Image(systemName: section.symbol)
        }
    }

    private var resultList: some View {
        let resultIndices = Dictionary(uniqueKeysWithValues: results.enumerated().map { ($0.element.id, $0.offset) })
        return ScrollViewReader { proxy in
            VStack(spacing: 0) {
                contentHeader
                Divider()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2, pinnedViews: [.sectionHeaders]) {
                        if results.isEmpty { emptyState }
                        ForEach(groupedResults, id: \.0) { group in
                            Section {
                                ForEach(group.1) { result in
                                    let index = resultIndices[result.id] ?? 0
                                    resultRow(
                                        result,
                                        isSelected: index == state.selection,
                                        isHovered: hoveredResultID == result.id
                                    )
                                        .id(result.id)
                                        .contextMenu {
                                            if result.libraryID != nil {
                                                Button(result.isFavorite ? "Remove from favorites" : "Add to favorites") {
                                                    store.toggleFavorite(of: result)
                                                }
                                            }
                                        }
                                        .onHover { hovering in
                                            withAnimation(.easeOut(duration: 0.1)) {
                                                hoveredResultID = hovering ? result.id : nil
                                            }
                                        }
                                }
                            } header: {
                                if !state.query.isEmpty {
                                    Text(group.0)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(.bar)
                                }
                            }
                        }
                    }
                    .padding(8)
                }
            }
            .onChange(of: state.selection) { _, newValue in
                guard let newValue, results.indices.contains(newValue) else { return }
                withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(results[newValue].id, anchor: .center) }
            }
        }
    }

    private var contentHeader: some View {
        HStack(spacing: 8) {
            Text(state.query.isEmpty ? selectedSection.title : "Search results")
                .font(.system(size: 12, weight: .semibold))
            Text("\(results.count)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
            Spacer()
            if state.query.isEmpty,
               selectedSection.systemShelf == .clipboard,
               !store.clipboardHistory.entries.isEmpty {
                Button("Clear", action: clearClipboardHistory)
                    .buttonStyle(.borderless)
                    .font(.system(size: 11, weight: .medium))
            }
            if state.query.isEmpty,
               let categoryID = selectedSection.categoryID,
               store.library.categories.first(where: { $0.id == categoryID })?.capabilities.contains("custom-entry") == true {
                Button { isPresentingNewItem = true } label: {
                    Label("New snippet", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11, weight: .medium))
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.2))
    }

    @ViewBuilder
    private var emptyState: some View {
        if selectedSection.systemShelf == .clipboard && !store.isClipboardHistoryEnabled && state.query.isEmpty {
            ContentUnavailableView {
                Label("Clipboard history is off", systemImage: "clipboard")
            } description: {
                Text("Enable it to keep your 50 most recent text copies.")
            } actions: {
                Button("Enable clipboard history", action: requestClipboardHistoryToggle)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 70)
        } else if selectedSection.systemShelf == .clipboard && store.clipboardHistory.entries.isEmpty && state.query.isEmpty {
            ContentUnavailableView {
                Label("Waiting for your next copy", systemImage: "clipboard")
            } description: {
                Text("Text copied after enabling history will appear here.")
            } actions: {
                Button("Turn off clipboard history", action: requestClipboardHistoryToggle)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 70)
        } else {
            ContentUnavailableView(
                emptyStateTitle,
                systemImage: state.query.isEmpty ? selectedSection.symbol : "magnifyingglass",
                description: Text(emptyStateDescription)
            )
            .frame(maxWidth: .infinity).padding(.vertical, 70)
        }
    }

    private var emptyStateTitle: String {
        if selectedSection.systemShelf == .recents && state.query.isEmpty { return "No recents yet" }
        if selectedSection.systemShelf == .favorites && state.query.isEmpty { return "No favorites yet" }
        return "Nothing found"
    }

    private var emptyStateDescription: String {
        if selectedSection.systemShelf == .recents && state.query.isEmpty { return "Copy an item and it will appear here." }
        if selectedSection.systemShelf == .favorites && state.query.isEmpty { return "Click an item's star, or select it and press Command-D." }
        return "Try a title, tag, category, or text value."
    }

    private func resultRow(_ result: ShelfResult, isSelected: Bool, isHovered: Bool) -> some View {
        HStack(spacing: 0) {
            Button { copy(result) } label: {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(result.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                        if !result.detail.isEmpty {
                            Text(result.detail).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 12)
                    Text(result.text)
                        .font(.system(size: 18, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.trailing)
                        .layoutPriority(1)
                    Image(systemName: "return")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .opacity(isSelected ? 1 : 0)
                        .frame(width: 14)
                }
                .padding(.leading, 12)
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.plain)

            if result.libraryID != nil {
                Button { store.toggleFavorite(of: result) } label: {
                    Image(systemName: result.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isHovered ? Color.accentColor : Color.secondary)
                        .frame(width: 34, height: 52)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(result.isFavorite || isHovered || isSelected ? 1 : 0)
                .help(result.isFavorite ? "Remove from favorites" : "Add to favorites")
                .accessibilityLabel(result.isFavorite ? "Remove from favorites" : "Add to favorites")
            }
        }
        .frame(minHeight: 52)
        .background(
            isSelected ? Color.primary.opacity(0.07) : isHovered ? Color.primary.opacity(0.035) : .clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .animation(.easeOut(duration: 0.1), value: isSelected)
        .contentShape(Rectangle())
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        guard !results.isEmpty else { return }
        switch direction {
        case .up: moveSelection(by: -1)
        case .down: moveSelection(by: 1)
        default: break
        }
    }

    private func handleSearchKey(_ keyPress: KeyPress) -> KeyPress.Result {
        if keyPress.key == .downArrow && keyPress.modifiers.isEmpty {
            state.moveSelection(by: 1, resultCount: results.count)
            return .handled
        }
        if keyPress.key == .upArrow && keyPress.modifiers.isEmpty {
            state.moveSelection(by: -1, resultCount: results.count)
            return .handled
        }
        if keyPress.key == .return && keyPress.modifiers.isEmpty {
            activateSelection()
            return .handled
        }
        if keyPress.key == .escape {
            dismiss()
            return .handled
        }
        if keyPress.key == .tab && keyPress.modifiers.contains(.control) {
            state.cycleSection(by: keyPress.modifiers.contains(.shift) ? -1 : 1, sections: store.sections)
            return .handled
        }
        return .ignored
    }

    private func moveSelection(by offset: Int) {
        state.moveSelection(by: offset, resultCount: results.count)
    }

    private func cycleSection(by offset: Int) {
        state.cycleSection(by: offset, sections: store.sections)
        searchFocused = true
    }

    private func selectSection(at index: Int) {
        state.selectSection(at: index, sections: store.sections)
        searchFocused = true
    }

    private func copy(_ result: ShelfResult) {
        guard Clipboard.copy(result.text) else {
            store.reportCopyFailure()
            return
        }
        store.ignoreCurrentClipboardChange()
        store.recordUse(of: result)
        dismiss()
    }

    private func addCustomItem(title: String, text: String, tags: [String], category: HandyCategory) -> Bool {
        guard let itemID = store.addCustomItem(text: text, title: title, tags: tags, categoryID: category.id),
              let sectionIndex = store.sections.firstIndex(where: { $0.categoryID == category.id }) else { return false }
        selectSection(at: sectionIndex)
        state.selection = store.results(in: store.sections[sectionIndex]).firstIndex { $0.libraryID == itemID }
        return true
    }
}

private struct NewCustomItemSheet: View {
    let category: HandyCategory
    let onSave: (String, String, [String]) -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var text = ""
    @State private var tagText = ""
    @State private var saveError: String?
    @FocusState private var titleFocused: Bool

    private var tags: [String] {
        let uniqueTags = Set(tagText.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty })
        return Array(uniqueTags.sorted().prefix(12))
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && title.utf8.count <= 120
            && text.utf8.count <= 10_000
            && tags.allSatisfy { $0.utf8.count <= 40 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("New \(category.title.dropLast(category.title.hasSuffix("s") ? 1 : 0).lowercased())")
                    .font(.system(size: 20, weight: .semibold))
                Text("Save text you want to find and copy again.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("Title").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                TextField("For example, Support sign-off", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .focused($titleFocused)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("Text").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                TextEditor(text: $text)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .frame(minHeight: 90)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.13)))
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("Tags, separated by commas").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                TextField("reply, work", text: $tagText).textFieldStyle(.roundedBorder)
            }
            if let saveError {
                Text(saveError)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    if onSave(
                        title.trimmingCharacters(in: .whitespacesAndNewlines),
                        text,
                        tags
                    ) {
                        dismiss()
                    } else {
                        saveError = "The snippet could not be saved. Your text is still here."
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear { titleFocused = true }
    }
}
