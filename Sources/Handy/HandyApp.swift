import AppKit
import SwiftUI

@main
struct HandyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        if let exitCode = HandyCLI.runIfRequested(Array(CommandLine.arguments.dropFirst())) {
            exit(exitCode)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            Button("Open Handy Palette") { appDelegate.openPalette() }
            Button("New snippet") { appDelegate.newSnippet() }
                .keyboardShortcut("n", modifiers: .command)
            Button("Reveal library.json") { appDelegate.revealLibrary() }
            Button(appDelegate.isClipboardHistoryEnabled ? "Disable clipboard history" : "Enable clipboard history") {
                appDelegate.toggleClipboardHistory()
            }
            Divider()
            Text("Option-Command-K")
            Button("Quit Handy Palette") { NSApp.terminate(nil) }
        } label: {
            Image(nsImage: HandyMenuBarIcon.image)
                .accessibilityLabel("Handy Palette")
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var palette = PaletteController()
    private var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let arguments = Array(CommandLine.arguments.dropFirst())
        hotKey = GlobalHotKey { [weak self] in self?.openPalette() }
        if hotKey?.register() != noErr {
            let alert = NSAlert()
            alert.messageText = "Handy could not register its shortcut"
            alert.informativeText = "Option-Command-K is already in use. You can still open Handy from its menu-bar icon. Shortcut customization is coming next."
            alert.runModal()
        }
        if arguments.first == "open"
            || CommandLine.arguments.contains("--open")
            || CommandLine.arguments.contains("--check-window")
            || CommandLine.arguments.contains("--check-keyboard")
            || CommandLine.arguments.contains("--check-focus")
            || CommandLine.arguments.contains("--check-snippet-focus")
            || CommandLine.arguments.contains("--check-search-performance") {
            DispatchQueue.main.async { [weak self] in self?.openPalette() }
        }
        if CommandLine.arguments.contains("--check-window") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("Handy palette: \(self.palette.diagnosticState)")
                exit(self.palette.diagnosticState.contains("visible=true occluded=false") ? 0 : 1)
            }
        }
        if CommandLine.arguments.contains("--check-keyboard") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.palette.runKeyboardDiagnostic { passed, detail in
                    print("Handy keyboard: \(passed ? "passed" : "failed") (\(detail))")
                    exit(passed ? 0 : 1)
                }
            }
        }
        if CommandLine.arguments.contains("--check-focus") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.palette.runFocusDiagnostic { passed, detail in
                    print("Handy focus: \(passed ? "passed" : "failed") (\(detail))")
                    exit(passed ? 0 : 1)
                }
            }
        }
        if CommandLine.arguments.contains("--check-snippet-focus") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.palette.runSnippetFocusDiagnostic { passed, detail in
                    print("Handy snippet focus: \(passed ? "passed" : "failed") (\(detail))")
                    exit(passed ? 0 : 1)
                }
            }
        }
        if CommandLine.arguments.contains("--check-search-performance") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.palette.runSearchPerformanceDiagnostic { passed, detail in
                    print("Handy search performance: \(passed ? "passed" : "failed") (\(detail))")
                    exit(passed ? 0 : 1)
                }
            }
        }
    }

    func openPalette() { palette.toggle() }

    func revealLibrary() { palette.revealLibrary() }
    func newSnippet() { palette.requestNewCustomItem() }
    var isClipboardHistoryEnabled: Bool { palette.isClipboardHistoryEnabled }
    func toggleClipboardHistory() { palette.toggleClipboardHistory() }
}
