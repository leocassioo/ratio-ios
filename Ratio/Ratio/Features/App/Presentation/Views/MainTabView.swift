//
//  MainTabView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            NavigationStack(path: $router.homePath) {
                HomeView()
                    .navigationDestination(for: AppRoute.self) { route in
                        routeDestination(for: route)
                    }
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(MainTab.home)

            NavigationStack(path: $router.subscriptionsPath) {
                SubscriptionsView()
                    .navigationDestination(for: AppRoute.self) { route in
                        routeDestination(for: route)
                    }
            }
            .tabItem {
                Label("Assinaturas", systemImage: "creditcard")
            }
            .tag(MainTab.subscriptions)

            NavigationStack(path: $router.groupsPath) {
                GroupsView()
                    .navigationDestination(for: AppRoute.self) { route in
                        routeDestination(for: route)
                    }
            }
            .tabItem {
                Label("Grupos", systemImage: "person.3")
            }
            .tag(MainTab.groups)

            NavigationStack(path: $router.advisorPath) {
                SmartAdvisorView()
                    .navigationDestination(for: AppRoute.self) { route in
                        routeDestination(for: route)
                    }
            }
            .tabItem {
                Label("Advisor", systemImage: "sparkles")
            }
            .tag(MainTab.advisor)

            NavigationStack(path: $router.settingsPath) {
                SettingsView()
                    .navigationDestination(for: AppRoute.self) { route in
                        routeDestination(for: route)
                    }
            }
            .tabItem {
                Label("Ajustes", systemImage: "gearshape")
            }
            .tag(MainTab.settings)
        }
        .sheet(item: $router.sheet) { sheet in
            sheetContent(for: sheet)
        }
        .fullScreenCover(item: $router.fullScreenCover) { cover in
            coverContent(for: cover)
        }
    }

    @ViewBuilder
    private func routeDestination(for route: AppRoute) -> some View {
        switch route {
        case .settings:
            SettingsView()
        case .billingHistory:
            BillingHistoryView()
        case .subscriptionBenefits:
            SubscriptionBenefitsView()
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: AppSheet) -> some View {
        switch sheet {
        case .upgradePrompt(let title, let subtitle, let benefits):
            UpgradePromptView(
                title: title,
                subtitle: subtitle,
                benefits: benefits,
                onViewPlans: {
                    router.dismissSheet()
                    router.present(.subscriptionBenefits)
                }
            )
        case .createSubscription(let ownerId, let onSave):
            NavigationStack {
                CreateSubscriptionView { newSubscription in
                    onSave(newSubscription)
                }
            }
        case .editSubscription(let subscription, let canDelete, let onDelete, let onSave):
            NavigationStack {
                EditSubscriptionView(
                    subscription: subscription,
                    canDelete: canDelete,
                    onDelete: onDelete,
                    onSave: onSave
                )
            }
        }
    }

    @ViewBuilder
    private func coverContent(for cover: AppFullScreenCover) -> some View {
        switch cover {
        case .subscriptionBenefits:
            NavigationStack {
                SubscriptionBenefitsView()
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppRouter())
}
