import Foundation
import Observation
import ServiceManagement

@MainActor @Observable
final class LoginItemController {
    static let shared = LoginItemController()

    private(set) var status: SMAppService.Status?
    private(set) var errorMessage: String?

    private init() {
        refresh()
    }

    var isPackagedApplication: Bool {
        Bundle.main.bundleURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame
    }

    var isEnabled: Bool { status == .enabled }

    var statusDescription: String {
        guard isPackagedApplication else { return "Open at login is available in Handy Palette.app." }
        switch status {
        case .enabled: return "Open at login is on."
        case .notRegistered: return "Open at login is off."
        case .requiresApproval: return "Open at login needs approval in System Settings."
        case .notFound: return "macOS could not find this app's login-item service."
        case nil: return "Open at login status is unavailable."
        @unknown default: return "Open at login has an unknown status."
        }
    }

    var needsSystemSettings: Bool { status == .requiresApproval }

    var diagnosticState: String {
        refresh()
        return "packaged=\(isPackagedApplication) status=\(statusDescription)"
    }

    func refresh() {
        guard isPackagedApplication else {
            status = nil
            return
        }
        status = SMAppService.mainApp.status
    }

    func setEnabled(_ shouldEnable: Bool) {
        guard isPackagedApplication else {
            errorMessage = "Open at login is available after installing Handy Palette.app."
            return
        }
        guard shouldEnable != isEnabled else { return }
        do {
            if shouldEnable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = "Open at login could not be updated: \(error.localizedDescription)"
        }
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
        refresh()
    }

    func dismissError() { errorMessage = nil }
}
