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
        static let pendingEmailChangeNotice = "pendingEmailChangeNotice"
        static let lastPushPromptDate = "lastPushPromptDate"
        static let lastAuthUserId = "lastAuthUserId"
        static let lastFcmToken = "lastFcmToken"
        static let lastSeenWhatsNewVersion = "lastSeenWhatsNewVersion"
        static let reviewPromptLastDate = "reviewPromptLastDate"
        static let reviewPromptCount = "reviewPromptCount"
        static let reviewFirstSessionDate = "reviewFirstSessionDate"
        static let reviewSessionCount = "reviewSessionCount"
        static let reviewLastSessionDate = "reviewLastSessionDate"
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

    func pendingEmailChangeNotice(defaultValue: Bool = false) -> Bool {
        if defaults.object(forKey: PrefKey.pendingEmailChangeNotice) == nil { return defaultValue }
        return defaults.bool(forKey: PrefKey.pendingEmailChangeNotice)
    }

    func setPendingEmailChangeNotice(_ value: Bool) {
        defaults.setValue(value, forKey: PrefKey.pendingEmailChangeNotice)
    }

    func lastPushPromptDate() -> String? {
        defaults.string(forKey: PrefKey.lastPushPromptDate)
    }

    func setLastPushPromptDate(_ value: String) {
        defaults.setValue(value, forKey: PrefKey.lastPushPromptDate)
    }

    func lastAuthUserId() -> String? {
        defaults.string(forKey: PrefKey.lastAuthUserId)
    }

    func setLastAuthUserId(_ value: String?) {
        defaults.setValue(value, forKey: PrefKey.lastAuthUserId)
    }

    func lastFcmToken() -> String? {
        defaults.string(forKey: PrefKey.lastFcmToken)
    }

    func setLastFcmToken(_ value: String?) {
        defaults.setValue(value, forKey: PrefKey.lastFcmToken)
    }

    func lastSeenWhatsNewVersion() -> String? {
        defaults.string(forKey: PrefKey.lastSeenWhatsNewVersion)
    }

    func setLastSeenWhatsNewVersion(_ value: String) {
        defaults.setValue(value, forKey: PrefKey.lastSeenWhatsNewVersion)
    }

    func reviewPromptLastDate() -> Date? {
        let interval = defaults.object(forKey: PrefKey.reviewPromptLastDate) as? TimeInterval
        return interval.map { Date(timeIntervalSince1970: $0) }
    }

    func setReviewPromptLastDate(_ value: Date?) {
        defaults.setValue(value?.timeIntervalSince1970, forKey: PrefKey.reviewPromptLastDate)
    }

    func reviewPromptCount() -> Int {
        defaults.integer(forKey: PrefKey.reviewPromptCount)
    }

    func setReviewPromptCount(_ value: Int) {
        defaults.setValue(value, forKey: PrefKey.reviewPromptCount)
    }

    func reviewFirstSessionDate() -> Date? {
        let interval = defaults.object(forKey: PrefKey.reviewFirstSessionDate) as? TimeInterval
        return interval.map { Date(timeIntervalSince1970: $0) }
    }

    func setReviewFirstSessionDate(_ value: Date?) {
        defaults.setValue(value?.timeIntervalSince1970, forKey: PrefKey.reviewFirstSessionDate)
    }

    func reviewSessionCount() -> Int {
        defaults.integer(forKey: PrefKey.reviewSessionCount)
    }

    func setReviewSessionCount(_ value: Int) {
        defaults.setValue(value, forKey: PrefKey.reviewSessionCount)
    }

    func reviewLastSessionDate() -> Date? {
        let interval = defaults.object(forKey: PrefKey.reviewLastSessionDate) as? TimeInterval
        return interval.map { Date(timeIntervalSince1970: $0) }
    }

    func setReviewLastSessionDate(_ value: Date?) {
        defaults.setValue(value?.timeIntervalSince1970, forKey: PrefKey.reviewLastSessionDate)
    }
}
