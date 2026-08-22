import AppKit
import SwiftUI
import HandyCore

private enum HandyFont {
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Anthrosevka Mono", size: size).weight(weight)
    }
}

@MainActor
final class PaletteController {
    private let store = LibraryStore()
    private var panel: NSPanel?

    func toggle() {
        if let panel, panel.isVisible { panel.orderOut(nil); return }
        show()
    }

    func show() {
        let view = PaletteView(store: store) { [weak self] in self?.panel?.orderOut(nil) }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
            styleMask: [.titled, .fullSizeContentView, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Handy"
        panel.titleVisibility = .hidden
        panel.backgroundColor = .windowBackgroundColor
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.center()
        panel.contentView = NSHostingView(rootView: view)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = panel
    }

    func revealLibrary() { store.openLibraryInFinder() }
}

struct PaletteView: View {
    @Bindable var store: LibraryStore
    let dismiss: () -> Void
    @State private var query = ""
    @State private var selection = 0
    @FocusState private var searchFocused: Bool

    private var items: [HandyItem] { store.items(matching: query) }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("HANDY")
                    .font(HandyFont.mono(11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(1.5)
                TextField("Search your shelf", text: $query)
                    .textFieldStyle(.plain)
                    .font(HandyFont.mono(22, weight: .medium))
                    .focused($searchFocused)
                    .onChange(of: query) { _, _ in selection = 0 }
                    .onSubmit(copySelection)
            }
            .padding(.horizontal, 20).padding(.vertical, 16)

            Divider()
            ScrollView {
                LazyVStack(spacing: 2) {
                    if items.isEmpty {
                        ContentUnavailableView("Nothing found", systemImage: "magnifyingglass", description: Text("Try an item title or tag."))
                            .padding(.vertical, 80)
                    }
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        Button { copy(item) } label: { row(item, isSelected: index == selection) }
                            .buttonStyle(.plain)
                            .onHover { hovering in if hovering { selection = index } }
                    }
                }.padding(8)
            }
            Divider()
            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(HandyFont.mono(11))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18).padding(.vertical, 8)
                Divider()
            }
            HStack {
                Text("↵ copy")
                Text("↑↓ navigate")
                Spacer()
                Text("local · private")
            }
            .font(HandyFont.mono(11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 18).padding(.vertical, 11)
        }
        .frame(minWidth: 500, minHeight: 360)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { searchFocused = true }
        .onExitCommand(perform: dismiss)
        .onMoveCommand { direction in
            guard !items.isEmpty else { return }
            selection = switch direction {
            case .up: max(0, selection - 1)
            case .down: min(items.count - 1, selection + 1)
            default: selection
            }
        }
    }

    private func row(_ item: HandyItem, isSelected: Bool) -> some View {
        HStack(spacing: 14) {
            Text(item.text).font(HandyFont.mono(23)).frame(width: 56, alignment: .center)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(HandyFont.mono(14, weight: .medium))
                Text(item.tags.joined(separator: " · ")).font(HandyFont.mono(11)).foregroundStyle(.secondary)
            }
            Spacer()
            if item.isPinned { Image(systemName: "pin.fill").foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(isSelected ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }

    private func copySelection() {
        guard items.indices.contains(selection) else { return }
        copy(items[selection])
    }

    private func copy(_ item: HandyItem) {
        guard Clipboard.copy(item.text) else {
            store.reportCopyFailure()
            return
        }
        dismiss()
    }
}
