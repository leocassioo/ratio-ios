//
//  AppRouter.swift
//  Ratio
//
//  Created by Codex on 23/12/25.
//

import FirebaseAuth
import SwiftUI
import Combine

enum AppRoute: Hashable {
    case settings
    case billingHistory
    case notificationsHistory
    case redeemInvite
    case subscriptionBenefits
    case editProfile
    case changeEmail
    case onboardingTutorial
    case signup
    case passwordReset
}

enum AppSheet: Identifiable, Equatable {
    case upgradePrompt(title: String, subtitle: String, benefits: [String])
    case createSubscription(ownerId: String, onSave: (SubscriptionItem) -> Void)
    case editSubscription(
        subscription: SubscriptionItem,
        canDelete: Bool,
        onDelete: () -> Void,
        onSave: (SubscriptionItem) -> Void
    )
    case createGroup(ownerId: String, ownerName: String, viewModel: GroupsViewModel)
    case editGroup(group: SharedGroup, ownerId: String, viewModel: GroupsViewModel)
    case groupDetail(group: SharedGroup, currentUserId: String?)
    case editProfile(user: User)
    case onboardingTutorial
    case whatsNew(state: WhatsNewState)

    var id: String {
        switch self {
        case .upgradePrompt:
            return "upgradePrompt"
        case .createSubscription:
            return "createSubscription"
        case .editSubscription(let subscription, _, _, _):
            return "editSubscription-\(subscription.id)"
        case .createGroup:
            return "createGroup"
        case .editGroup(let group, _, _):
            return "editGroup-\(group.id)"
        case .groupDetail(let group, _):
            return "groupDetail-\(group.id)"
        case .editProfile(let user):
            return "editProfile-\(user.uid)"
        case .onboardingTutorial:
            return "onboardingTutorial"
        case .whatsNew:
            return "whatsNew"
        }
    }

    static func == (lhs: AppSheet, rhs: AppSheet) -> Bool {
        lhs.id == rhs.id
    }
}

enum AppFullScreenCover: Identifiable, Equatable {
    case subscriptionBenefits

    var id: String {
        switch self {
        case .subscriptionBenefits:
            return "subscriptionBenefits"
        }
    }

    static func == (lhs: AppFullScreenCover, rhs: AppFullScreenCover) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: MainTab = .home
    @Published var pendingGroupId: String?
    @Published var homePath = NavigationPath()
    @Published var subscriptionsPath = NavigationPath()
    @Published var groupsPath = NavigationPath()
    @Published var advisorPath = NavigationPath()
    @Published var settingsPath = NavigationPath()
    @Published var authPath = NavigationPath()

    @Published var sheet: AppSheet?
    @Published var fullScreenCover: AppFullScreenCover?

    func push(_ route: AppRoute, in tab: MainTab = .home) {
        switch tab {
        case .home:
            homePath.append(route)
        case .subscriptions:
            subscriptionsPath.append(route)
        case .groups:
            groupsPath.append(route)
        case .advisor:
            advisorPath.append(route)
        case .settings:
            settingsPath.append(route)
        }
    }

    func pop(in tab: MainTab = .home) {
        switch tab {
        case .home:
            if !homePath.isEmpty { homePath.removeLast() }
        case .subscriptions:
            if !subscriptionsPath.isEmpty { subscriptionsPath.removeLast() }
        case .groups:
            if !groupsPath.isEmpty { groupsPath.removeLast() }
        case .advisor:
            if !advisorPath.isEmpty { advisorPath.removeLast() }
        case .settings:
            if !settingsPath.isEmpty { settingsPath.removeLast() }
        }
    }

    func pushAuth(_ route: AppRoute) {
        authPath.append(route)
    }

    func popAuth() {
        if !authPath.isEmpty { authPath.removeLast() }
    }

    func present(_ sheet: AppSheet) {
        self.sheet = sheet
    }

    func present(_ fullScreenCover: AppFullScreenCover) {
        self.fullScreenCover = fullScreenCover
    }

    func dismissSheet() {
        sheet = nil
    }

    func dismissFullScreenCover() {
        fullScreenCover = nil
    }

    func route(to tab: MainTab, groupId: String? = nil) {
        selectedTab = tab
        pendingGroupId = groupId
    }
}
