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
        static let didSkipPushPermission = "didSkipPushPermission"
        static let isProUser = "isProUser"
        static let primaryCurrencyCode = "primaryCurrencyCode"
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

    func isProUser(defaultValue: Bool = false) -> Bool {
        if defaults.object(forKey: PrefKey.isProUser) == nil { return defaultValue }
        return defaults.bool(forKey: PrefKey.isProUser)
    }

    func setIsProUser(_ value: Bool) {
        defaults.setValue(value, forKey: PrefKey.isProUser)
    }

    func primaryCurrencyCode(defaultValue: String = "BRL") -> String {
        defaults.string(forKey: PrefKey.primaryCurrencyCode) ?? defaultValue
    }

    func setPrimaryCurrencyCode(_ value: String) {
        defaults.setValue(value, forKey: PrefKey.primaryCurrencyCode)
    }
}
