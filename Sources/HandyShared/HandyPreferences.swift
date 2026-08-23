import Foundation

public enum HandyPreferences {
    public static let clipboardHistoryEnabledKey = "clipboardHistoryEnabled"

    public static var clipboardHistoryEnabled: Bool {
        get { defaults.bool(forKey: clipboardHistoryEnabledKey) }
        set { defaults.set(newValue, forKey: clipboardHistoryEnabledKey) }
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: "io.github.aloki-alok.handy-palette.shared")!
    }
}
