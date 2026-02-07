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
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @AppStorage(PreferencesStore.PrefKey.lastSeenWhatsNewVersion) private var lastSeenWhatsNewVersion: String = ""
    @AppStorage(PreferencesStore.PrefKey.appTheme) private var appThemeRaw: String = AppTheme.system.rawValue
    @AppStorage(PreferencesStore.PrefKey.appLanguage) private var appLanguageRaw: String = AppLanguage.system.rawValue
    @AppStorage(PreferencesStore.PrefKey.primaryCurrencyCode) private var primaryCurrencyCodeRaw: String = "BRL"
    private let analytics = AnalyticsService.shared

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
        .onAppear {
            setBaseUserProperties()
            Task { await refreshWhatsNewIfNeeded() }
        }
        .onChange(of: appThemeRaw) { _, newValue in
            analytics.setUserProperty(.theme, value: newValue)
        }
        .onChange(of: appLanguageRaw) { _, newValue in
            analytics.setUserProperty(.app_language, value: newValue)
        }
        .onChange(of: subscriptionManager.hasProAccess) { _, newValue in
            analytics.setUserProperty(.is_pro, value: newValue)
        }
        .onChange(of: primaryCurrencyCodeRaw) { _, newValue in
            analytics.setUserProperty(.primary_currency, value: newValue)
        }
        .onChange(of: router.selectedTab) { _, newValue in
            analytics.track(.tab_select, parameters: ["tab": newValue.rawValue])
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await refreshWhatsNewIfNeeded() }
            }
        }
    }

    private func setBaseUserProperties() {
        analytics.setUserProperty(.theme, value: appThemeRaw)
        analytics.setUserProperty(.app_language, value: appLanguageRaw)
        analytics.setUserProperty(.is_pro, value: subscriptionManager.hasProAccess)
        analytics.setUserProperty(.primary_currency, value: primaryCurrencyCodeRaw)

        #if targetEnvironment(macCatalyst)
        analytics.setUserProperty(.platform, value: "mac_catalyst")
        #else
        analytics.setUserProperty(.platform, value: "ios")
        #endif

        if let region = Locale.current.region?.identifier {
            analytics.setUserProperty(.locale_region, value: region)
        }
    }

    @ViewBuilder
    private func routeDestination(for route: AppRoute) -> some View {
        switch route {
        case .settings:
            SettingsView()
        case .billingHistory:
            BillingHistoryView()
        case .notificationsHistory:
            NotificationsHistoryView()
        case .redeemInvite:
            RedeemInviteView()
        case .subscriptionBenefits:
            SubscriptionBenefitsView(source: .unknown)
        case .editProfile:
            if let user = Auth.auth().currentUser {
                EditProfileView(user: user)
            } else {
                Text("Perfil indisponível")
            }
        case .changeEmail:
            ChangeEmailView()
        case .onboardingTutorial:
            OnboardingView(showsFinishButton: false) {
                router.pop(in: .settings)
            }
        case .signup:
            SignupView()
        case .passwordReset:
            PasswordResetView()
        case .deleteAccount:
            DeleteAccountView()
        case .receiptPreview(let receipt, let groupId, let memberId):
            ReceiptPreviewView(receipt: receipt, groupId: groupId, memberId: memberId)
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: AppSheet) -> some View {
        switch sheet {
        case .upgradePrompt(let title, let subtitle, let benefits, let source):
            UpgradePromptView(
                title: title,
                subtitle: subtitle,
                benefits: benefits,
                source: source,
                onViewPlans: { selectedSource in
                    router.dismissSheet()
                    router.present(.subscriptionBenefits(source: selectedSource))
                }
            )
        case .createSubscription(let ownerId, let onSave):
            NavigationStack {
                CreateSubscriptionView(ownerId: ownerId) { newSubscription in
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
        case .whatsNew(let state):
            WhatsNewView(
                state: state,
                onContinue: { markWhatsNewSeen(version: state.payload.version) },
                onUpdate: { url in
                    if let url {
                        openURL(url)
                    }
                    markWhatsNewSeen(version: state.payload.version)
                }
            )
            .presentationDetents([.large])
        case .homeInsight(let item):
            HomeInsightDetailSheetView(
                item: item,
                onOpen: item.destination == nil ? nil : {
                    if let destination = item.destination {
                        router.route(to: destination)
                    }
                }
            )
            .presentationDetents([.fraction(0.6)])
        }
    }

    @ViewBuilder
    private func coverContent(for cover: AppFullScreenCover) -> some View {
        switch cover {
        case .subscriptionBenefits(let source):
            NavigationStack {
                SubscriptionBenefitsView(source: source)
            }
        }
    }

    @MainActor
    private func refreshWhatsNewIfNeeded() async {
        guard router.sheet == nil else { return }
        _ = await RemoteConfigService.shared.fetchAndActivate()
        guard let payload = RemoteConfigService.shared.whatsNewPayload else { return }
        guard lastSeenWhatsNewVersion != payload.version else { return }

        let slides = payload.slides(for: locale)
        guard !slides.isEmpty else { return }

        let currentVersion = AppVersion.current
        let isOutdated = payload.minVersion.map { AppVersion.isLower(currentVersion, than: $0) } ?? false
        let state = WhatsNewState(payload: payload, slides: slides, isOutdated: isOutdated, source: .auto)
        router.present(.whatsNew(state: state))
    }

    private func markWhatsNewSeen(version: String) {
        lastSeenWhatsNewVersion = version
        router.dismissSheet()
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppRouter())
        .environmentObject(SubscriptionManager.shared)
}
