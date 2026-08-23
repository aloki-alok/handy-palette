import AppKit
import SwiftUI
import KanaShared

@main
struct KanaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var loginItem = LoginItemController.shared

    var body: some Scene {
        MenuBarExtra {
            Button("Open Kana") { appDelegate.openPalette() }
            Button("New snippet") { appDelegate.newSnippet() }
                .keyboardShortcut("n", modifiers: .command)
            Button("Reveal library.json") { appDelegate.revealLibrary() }
            Button(appDelegate.isClipboardHistoryEnabled ? "Disable clipboard history" : "Enable clipboard history") {
                appDelegate.toggleClipboardHistory()
            }
            Divider()
            Toggle(
                "Open at login",
                isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                )
            )
                .disabled(!loginItem.isPackagedApplication)
                .onAppear { loginItem.refresh() }
            if loginItem.needsSystemSettings {
                Button("Open Login Items settings") { loginItem.openSystemSettings() }
            }
            if let errorMessage = loginItem.errorMessage {
                Text(errorMessage)
                Button("Dismiss") { loginItem.dismissError() }
            }
            Divider()
            Text("Option-Command-K")
            Button("Quit Kana") { NSApp.terminate(nil) }
        } label: {
            Image(nsImage: KanaMenuBarIcon.image)
                .accessibilityLabel("Kana")
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var palette = PaletteController()
    private var hotKey: GlobalHotKey?
    private let loginItem = LoginItemController.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let arguments = Array(CommandLine.arguments.dropFirst())
        hotKey = GlobalHotKey { [weak self] in self?.openPalette() }
        if hotKey?.register() != noErr {
            let alert = NSAlert()
            alert.messageText = "Kana could not register its shortcut"
            alert.informativeText = "Option-Command-K is already in use. You can still open Kana from its menu-bar icon. Shortcut customization is coming next."
            alert.runModal()
        }
        if arguments.first == "open"
            || CommandLine.arguments.contains("--open")
            || CommandLine.arguments.contains("--check-window")
            || CommandLine.arguments.contains("--check-keyboard")
            || CommandLine.arguments.contains("--check-focus")
            || CommandLine.arguments.contains("--check-background-focus")
            || CommandLine.arguments.contains("--check-snippet-focus")
            || CommandLine.arguments.contains("--check-search-performance") {
            DispatchQueue.main.async { [weak self] in self?.openPalette() }
        }
        if CommandLine.arguments.contains("--check-window") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let state = self.palette.diagnosticState
                print("Kana palette: \(state)")
                exit(state.contains("visible=true") && state.contains("occluded=false") ? 0 : 1)
            }
        }
        if CommandLine.arguments.contains("--check-keyboard") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.palette.runKeyboardDiagnostic { passed, detail in
                    print("Kana keyboard: \(passed ? "passed" : "failed") (\(detail))")
                    exit(passed ? 0 : 1)
                }
            }
        }
        if CommandLine.arguments.contains("--check-focus") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.palette.runFocusDiagnostic { passed, detail in
                    print("Kana focus: \(passed ? "passed" : "failed") (\(detail))")
                    exit(passed ? 0 : 1)
                }
            }
        }
        if CommandLine.arguments.contains("--check-background-focus") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.palette.runBackgroundFocusDiagnostic { passed, detail in
                    print("Kana background focus: \(passed ? "passed" : "failed") (\(detail))")
                    exit(passed ? 0 : 1)
                }
            }
        }
        if CommandLine.arguments.contains("--check-snippet-focus") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.palette.runSnippetFocusDiagnostic { passed, detail in
                    print("Kana snippet focus: \(passed ? "passed" : "failed") (\(detail))")
                    exit(passed ? 0 : 1)
                }
            }
        }
        if CommandLine.arguments.contains("--check-search-performance") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.palette.runSearchPerformanceDiagnostic { passed, detail in
                    print("Kana search performance: \(passed ? "passed" : "failed") (\(detail))")
                    exit(passed ? 0 : 1)
                }
            }
        }
        if CommandLine.arguments.contains("--check-login-item") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("Kana login item: \(self.loginItem.diagnosticState)")
                exit(self.loginItem.isPackagedApplication ? 0 : 1)
            }
        }
    }

    func openPalette() { palette.toggle() }

    func showPalette() { palette.show() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPalette()
        return true
    }

    func revealLibrary() { palette.revealLibrary() }
    func newSnippet() { palette.requestNewCustomItem() }
    var isClipboardHistoryEnabled: Bool { palette.isClipboardHistoryEnabled }
    func toggleClipboardHistory() { palette.toggleClipboardHistory() }
}
