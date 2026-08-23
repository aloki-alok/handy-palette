import Foundation

public struct HandyPreferencesStore {
    private let defaults: UserDefaults
    private let legacyDomainNames: [String]

    public init(suiteName: String, legacyDomainNames: [String] = []) {
        defaults = UserDefaults(suiteName: suiteName)!
        self.legacyDomainNames = legacyDomainNames
    }

    public var clipboardHistoryEnabled: Bool {
        migrateClipboardPreferenceIfNeeded()
        return defaults.bool(forKey: HandyPreferences.clipboardHistoryEnabledKey)
    }

    public func setClipboardHistoryEnabled(_ enabled: Bool) {
        migrateClipboardPreferenceIfNeeded()
        defaults.set(enabled, forKey: HandyPreferences.clipboardHistoryEnabledKey)
    }

    private func migrateClipboardPreferenceIfNeeded() {
        let migrationKey = "migration.clipboardHistoryEnabled.v1"
        guard !defaults.bool(forKey: migrationKey) else { return }
        if defaults.object(forKey: HandyPreferences.clipboardHistoryEnabledKey) == nil {
            for domainName in legacyDomainNames {
                guard let value = UserDefaults.standard.persistentDomain(forName: domainName)?[HandyPreferences.clipboardHistoryEnabledKey] as? Bool else {
                    continue
                }
                defaults.set(value, forKey: HandyPreferences.clipboardHistoryEnabledKey)
                break
            }
        }
        defaults.set(true, forKey: migrationKey)
    }
}

public enum HandyPreferences {
    public static let clipboardHistoryEnabledKey = "clipboardHistoryEnabled"

    public static var clipboardHistoryEnabled: Bool {
        get { store.clipboardHistoryEnabled }
        set { store.setClipboardHistoryEnabled(newValue) }
    }

    private static var store: HandyPreferencesStore {
        HandyPreferencesStore(
            suiteName: "io.github.aloki-alok.handy-palette.shared",
            legacyDomainNames: ["Handy", "handy-palette"]
        )
    }
}
