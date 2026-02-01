//
//  OnboardingViewModel.swift
//  Ratio
//
//  Created by Codex on 31/01/26.
//

import Foundation
import Combine

final class OnboardingViewModel: ObservableObject {
    private let analytics: AnalyticsService

    init(analytics: AnalyticsService = .shared) {
        self.analytics = analytics
    }

    func trackOnboardingView(stepIndex: Int) {
        analytics.track(.onboarding_view, parameters: ["step_index": stepIndex])
    }

    func trackOnboardingComplete() {
        analytics.track(.onboarding_complete)
    }
}
