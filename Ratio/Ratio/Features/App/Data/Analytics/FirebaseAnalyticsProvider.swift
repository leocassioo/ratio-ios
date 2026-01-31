//
//  FirebaseAnalyticsProvider.swift
//  Ratio
//
//  Firebase Analytics implementation.
//

import Foundation
import FirebaseAnalytics

final class FirebaseAnalyticsProvider: AnalyticsProvider {
    func logEvent(name: String, parameters: [String: Any]?) {
        Analytics.logEvent(name, parameters: parameters)
    }

    func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    func logScreenView(name: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: name
        ])
    }
}
