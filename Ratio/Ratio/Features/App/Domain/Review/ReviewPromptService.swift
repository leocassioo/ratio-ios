//
//  ReviewPromptService.swift
//  Ratio
//
//  Created by Codex on 15/02/26.
//

import StoreKit
import UIKit

@MainActor
final class ReviewPromptService {
    static let shared = ReviewPromptService()

    enum Trigger {
        case subscriptionCreated
        case groupCreated
        case paymentApproved
        case receiptSubmitted
        case engagementMilestone
    }

    private let preferences: PreferencesStore
    private let minimumDaysBetweenPrompts = 90
    private let minimumSessionsForEngagement = 3
    private let minimumDaysForEngagement = 7
    private let maximumPromptCount = 3

    init(preferences: PreferencesStore = .shared) {
        self.preferences = preferences
    }

    func recordAppSession() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastSession = preferences.reviewLastSessionDate(),
           calendar.isDate(lastSession, inSameDayAs: today) {
            return
        }

        preferences.setReviewLastSessionDate(today)
        let newCount = preferences.reviewSessionCount() + 1
        preferences.setReviewSessionCount(newCount)

        if preferences.reviewFirstSessionDate() == nil {
            preferences.setReviewFirstSessionDate(today)
        }

        requestIfAppropriate(trigger: .engagementMilestone)
    }

    func requestIfAppropriate(trigger: Trigger) {
        guard shouldPrompt(trigger: trigger) else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }

        SKStoreReviewController.requestReview(in: scene)
        let newCount = preferences.reviewPromptCount() + 1
        preferences.setReviewPromptCount(newCount)
        preferences.setReviewPromptLastDate(Date())
    }

    private func shouldPrompt(trigger: Trigger) -> Bool {
        let now = Date()
        if let lastPrompt = preferences.reviewPromptLastDate() {
            let elapsedDays = Calendar.current.dateComponents([.day], from: lastPrompt, to: now).day ?? 0
            if elapsedDays < minimumDaysBetweenPrompts {
                return false
            }
        }

        if preferences.reviewPromptCount() >= maximumPromptCount {
            return false
        }

        if trigger == .engagementMilestone {
            let sessions = preferences.reviewSessionCount()
            guard sessions >= minimumSessionsForEngagement else { return false }

            guard let firstSession = preferences.reviewFirstSessionDate() else { return false }
            let elapsedDays = Calendar.current.dateComponents([.day], from: firstSession, to: now).day ?? 0
            guard elapsedDays >= minimumDaysForEngagement else { return false }
        }

        return true
    }
}
