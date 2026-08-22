import AppKit
import SwiftUI

@main
struct HandyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Handy", systemImage: "sparkles") {
            Button("Open Handy") { appDelegate.openPalette() }
            Button("Reveal library.json") { appDelegate.revealLibrary() }
            Divider()
            Text("Option-Command-Space")
            Button("Quit Handy") { NSApp.terminate(nil) }
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let palette = PaletteController()
    private var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotKey = GlobalHotKey { [weak self] in self?.openPalette() }
        if hotKey?.register() != noErr {
            let alert = NSAlert()
            alert.messageText = "Handy could not register its shortcut"
            alert.informativeText = "Option-Command-Space is already in use. You can still open Handy from its menu-bar icon. Shortcut customization is coming next."
            alert.runModal()
        }
    }

    func openPalette() { palette.toggle() }

    func revealLibrary() { palette.revealLibrary() }
}
