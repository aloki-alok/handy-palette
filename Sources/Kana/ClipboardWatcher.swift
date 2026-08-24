import AppKit
import KanaCore
import KanaShared

@MainActor
final class ClipboardWatcher {
    private static let pollingInterval: TimeInterval = 1
    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    private let onText: (String) -> Void

    init(onText: @escaping (String) -> Void) {
        self.onText = onText
    }

    func start() {
        guard timer == nil else { return }
        lastChangeCount = NSPasteboard.general.changeCount
        let timer = Timer(timeInterval: Self.pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.readIfChanged() }
        }
        // Clipboard monitoring is opt-in and polling is the only NSPasteboard change signal.
        // Tolerance lets macOS coalesce this background wakeup with nearby work.
        timer.tolerance = 0.25
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func ignoreCurrentChange() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    private func readIfChanged() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        let availableTypes = pasteboard.types ?? []
        guard ClipboardHistory.allowsCapture(pasteboardTypeNames: availableTypes.map(\.rawValue)) else { return }
        guard let text = pasteboard.string(forType: .string) else { return }
        onText(text)
    }
}
