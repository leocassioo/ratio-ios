//
//  AnalyticsService.swift
//  Ratio
//
//  Centralized analytics service with pluggable providers.
//

import Foundation

protocol AnalyticsProvider {
    func logEvent(name: String, parameters: [String: Any]?)
    func setUserProperty(_ value: String?, forName name: String)
    func logScreenView(name: String)
}

final class AnalyticsService {
    static let shared = AnalyticsService()

    private let provider: AnalyticsProvider

    init(provider: AnalyticsProvider = FirebaseAnalyticsProvider()) {
        self.provider = provider
    }

    func track(_ event: AnalyticsEvent) {
        provider.logEvent(name: event.name, parameters: sanitize(event.parameters))
    }

    func track(_ name: AnalyticsEventName, parameters: [String: Any]? = nil) {
        provider.logEvent(name: name.rawValue, parameters: sanitize(parameters))
    }

    func setUserProperty(_ name: AnalyticsUserProperty, value: String?) {
        provider.setUserProperty(value, forName: name.rawValue)
    }

    func setUserProperty(_ name: AnalyticsUserProperty, value: Bool) {
        provider.setUserProperty(value ? "true" : "false", forName: name.rawValue)
    }

    func setUserProperty(_ name: AnalyticsUserProperty, value: Int) {
        provider.setUserProperty(String(value), forName: name.rawValue)
    }

    func setUserProperty(_ name: AnalyticsUserProperty, value: Double) {
        provider.setUserProperty(String(value), forName: name.rawValue)
    }

    func screenView(_ name: AnalyticsScreenName) {
        provider.logScreenView(name: name.rawValue)
    }

    private func sanitize(_ parameters: [String: Any]?) -> [String: Any]? {
        guard let parameters else { return nil }
        var sanitized: [String: Any] = [:]
        for (key, value) in parameters {
            switch value {
            case let v as String:
                sanitized[key] = v
            case let v as Int:
                sanitized[key] = v
            case let v as Double:
                sanitized[key] = v
            case let v as Float:
                sanitized[key] = v
            case let v as Bool:
                sanitized[key] = NSNumber(value: v)
            case let v as NSNumber:
                sanitized[key] = v
            default:
                continue
            }
        }
        return sanitized.isEmpty ? nil : sanitized
    }
}
