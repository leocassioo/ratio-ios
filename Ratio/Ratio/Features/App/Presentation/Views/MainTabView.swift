//
//  MainTabView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import FirebaseAuth
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
        case .editProfile:
            if let user = Auth.auth().currentUser {
                EditProfileView(user: user)
            } else {
                Text("Perfil indisponível")
            }
        case .onboardingTutorial:
            OnboardingView(showsFinishButton: false) {
                router.pop(in: .settings)
            }
        case .signup:
            SignupView()
        case .passwordReset:
            PasswordResetView()
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
        case .createGroup(let ownerId, let ownerName, let viewModel):
            NavigationStack {
                CreateGroupView(
                    viewModel: viewModel,
                    ownerId: ownerId,
                    ownerName: ownerName
                )
            }
        case .editGroup(let group, let ownerId, let viewModel):
            NavigationStack {
                EditGroupView(
                    viewModel: viewModel,
                    group: group,
                    ownerId: ownerId
                )
            }
        case .groupDetail(let group, let currentUserId):
            NavigationStack {
                GroupDetailView(
                    group: group,
                    currentUserId: currentUserId
                )
            }
        case .editProfile(let user):
            NavigationStack {
                EditProfileView(user: user)
            }
        case .onboardingTutorial:
            NavigationStack {
                OnboardingView(showsFinishButton: false) {
                    router.dismissSheet()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            router.dismissSheet()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
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
