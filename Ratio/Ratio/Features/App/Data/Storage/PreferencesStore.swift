//
//  PreferencesStore.swift
//  Ratio
//
//  Created by Codex on 23/12/25.
//

import Foundation

final class PreferencesStore {
    static let shared = PreferencesStore()

    enum PrefKey {
        static let hasSeenOnboarding = "hasSeenOnboarding"
        static let appTheme = "appTheme"
        static let appLanguage = "appLanguage"
    }

    private let defaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
    }

    func hasSeenOnboarding(defaultValue: Bool = false) -> Bool {
        if defaults.object(forKey: PrefKey.hasSeenOnboarding) == nil { return defaultValue }
        return defaults.bool(forKey: PrefKey.hasSeenOnboarding)
    }

    func setHasSeenOnboarding(_ value: Bool) {
        defaults.setValue(value, forKey: PrefKey.hasSeenOnboarding)
    }
}
