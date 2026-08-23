import Foundation

public struct KanaPreferencesStore {
    private let defaults: UserDefaults
    private let legacyDomainNames: [String]

    public init(suiteName: String, legacyDomainNames: [String] = []) {
        defaults = UserDefaults(suiteName: suiteName)!
        self.legacyDomainNames = legacyDomainNames
    }

    public var clipboardHistoryEnabled: Bool {
        migrateClipboardPreferenceIfNeeded()
        return defaults.bool(forKey: KanaPreferences.clipboardHistoryEnabledKey)
    }

    public func setClipboardHistoryEnabled(_ enabled: Bool) {
        migrateClipboardPreferenceIfNeeded()
        defaults.set(enabled, forKey: KanaPreferences.clipboardHistoryEnabledKey)
    }

    private func migrateClipboardPreferenceIfNeeded() {
        let migrationKey = "migration.clipboardHistoryEnabled.v1"
        guard !defaults.bool(forKey: migrationKey) else { return }
        if defaults.object(forKey: KanaPreferences.clipboardHistoryEnabledKey) == nil {
            for domainName in legacyDomainNames {
                guard let value = UserDefaults.standard.persistentDomain(forName: domainName)?[KanaPreferences.clipboardHistoryEnabledKey] as? Bool else {
                    continue
                }
                defaults.set(value, forKey: KanaPreferences.clipboardHistoryEnabledKey)
                break
            }
        }
        defaults.set(true, forKey: migrationKey)
    }
}

public enum KanaPreferences {
    public static let clipboardHistoryEnabledKey = "clipboardHistoryEnabled"

    public static var clipboardHistoryEnabled: Bool {
        get { store.clipboardHistoryEnabled }
        set { store.setClipboardHistoryEnabled(newValue) }
    }

    private static var store: KanaPreferencesStore {
        KanaPreferencesStore(
            suiteName: "io.github.aloki-alok.kana.shared",
            legacyDomainNames: [
                "io.github.aloki-alok.handy-palette.shared",
                "io.github.aloki-alok.handy-palette",
                "Handy",
                "handy-palette"
            ]
        )
    }
}
