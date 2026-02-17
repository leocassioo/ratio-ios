//
//  HomeView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI
import FirebaseAuth

struct HomeView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var notificationsBadgeViewModel = NotificationsBadgeViewModel()
    @StateObject private var pushPermissionState = PushPermissionState()
    @AppStorage(PreferencesStore.PrefKey.primaryCurrencyCode) private var primaryCurrencyCodeRaw: String = "BRL"
    @AppStorage(PreferencesStore.PrefKey.lastPushPromptDate) private var lastPushPromptDateRaw: String = ""
    @State private var showPushPrompt = false
    @State private var didLogScreen = false
    private let analytics = AnalyticsService.shared
    private let upcomingPayments: [UpcomingPaymentItem] = [
        UpcomingPaymentItem(
            subscriptionId: nil,
            groupId: nil,
            name: "SmartFit",
            initials: "S",
            category: .fitness,
            amount: 119.90,
            currencyCode: "BRL",
            dueDate: Date().addingTimeInterval(2 * 24 * 60 * 60),
            period: "Mensal",
            logoURL: nil
        ),
        UpcomingPaymentItem(
            subscriptionId: nil,
            groupId: nil,
            name: "Netflix Premium",
            initials: "N",
            category: .streaming,
            amount: 55.90,
            currencyCode: "BRL",
            dueDate: Date().addingTimeInterval(5 * 24 * 60 * 60),
            period: "Mensal",
            logoURL: nil
        ),
        UpcomingPaymentItem(
            subscriptionId: nil,
            groupId: nil,
            name: "Spotify Duo",
            initials: "S",
            category: .music,
            amount: 27.90,
            currencyCode: "BRL",
            dueDate: Date().addingTimeInterval(12 * 24 * 60 * 60),
            period: "Mensal",
            logoURL: nil
        )
    ]
    private let categorySpends: [CategorySpendItem] = [
        CategorySpendItem(label: "Streaming", amount: 132.80, currencyCode: "BRL", color: Color(.systemIndigo)),
        CategorySpendItem(label: "Saúde", amount: 119.90, currencyCode: "BRL", color: Color(.systemTeal)),
        CategorySpendItem(label: "Música", amount: 27.90, currencyCode: "BRL", color: Color(.systemPink)),
        CategorySpendItem(label: "Outros", amount: 57.02, currencyCode: "BRL", color: Color(.systemOrange))
    ]
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    HomeSummaryCardView(
                        totalAmount: viewModel.totalMonthlyAmount,
                        currencyCode: viewModel.currencyCode,
                        deltaText: summarySubtitle,
                        estimatedBRL: viewModel.estimatedBRL(forAmount: viewModel.totalMonthlyAmount, currencyCode: viewModel.currencyCode),
                        onIndicatorTap: {
                            analytics.track(.home_total_monthly_tap)
                            router.present(.homeInsight(item: summaryDetailItem))
                        }
                    )

                    if pushPermissionState.status == .notDetermined || pushPermissionState.status == .denied {
                        PushPermissionBannerView(
                            status: pushPermissionState.status,
                            onPrimaryAction: {
                                if pushPermissionState.status == .denied {
                                    openAppSettings()
                                } else {
                                    showPushPrompt = true
                                }
                            }
                        )
                    }

                    if !viewModel.isLoading && !viewModel.hasSubscriptions && !viewModel.hasGroups {
                        HomeEmptyStateView(
                            onAddSubscription: {
                                router.route(to: .subscriptions)
                            },
                                onCreateGroup: {
                                    router.route(to: .groups)
                                }
                            )
                            .onAppear {
                                analytics.track(.home_empty_state_view)
                            }
                        }
                    if viewModel.hasMixedCurrencies {
                        let preferredCurrencyCode = primaryCurrencyCodeRaw
                        HomeCurrencySummaryView(
                            totalsByCurrency: viewModel.totalsByCurrency,
                            estimatedByCurrency: viewModel.estimatedTotalsByCurrency(preferredCurrencyCode: preferredCurrencyCode),
                            preferredCurrencyCode: preferredCurrencyCode
                        )
                    }

                    if !viewModel.insights.isEmpty {
                        HomeInsightsRowView(insights: viewModel.insights) { insight in
                            analytics.track(.home_insight_tap, parameters: ["insight_type": insight.icon])
                            router.present(.homeInsight(item: insight))
                        }
                    }

                    HomeUpcomingSectionView(
                        items: viewModel.upcomingPayments,
                        destinationTab: upcomingDestination,
                        estimated: { item in
                            let preferredCurrency = primaryCurrencyCodeRaw
                            guard let estimated = viewModel.estimatedAmount(
                                forAmount: item.amount,
                                currencyCode: item.currencyCode,
                                preferredCurrencyCode: preferredCurrency
                            ) else {
                                return nil
                            }
                            return (estimated, preferredCurrency)
                        },
                        onTap: { item in
                            analytics.track(.home_upcoming_payment_tap, parameters: [
                                "item_type": item.groupId != nil ? "group" : "subscription"
                            ])
                            if let groupId = item.groupId {
                                router.route(to: .groups, groupId: groupId)
                            } else if let subscriptionId = item.subscriptionId {
                                router.pendingSubscriptionId = subscriptionId
                                router.route(to: .subscriptions)
                            }
                        }
                    )

                    HomeCategoryDonutCardView(
                        items: viewModel.categorySpends,
                        onCategoryTap: { category in
                            analytics.track(.home_chart_category_tap, parameters: ["category": category])
                        }
                    )

                    HomeMonthlySpendsCardView(
                        items: viewModel.monthlySpends,
                        categoryBreakdown: viewModel.categorySpends,
                        currencyCode: viewModel.monthlySpendsCurrencyCode,
                        onMonthTap: { month in
                            analytics.track(.home_chart_monthly_tap, parameters: ["month_index": month])
                        }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))

            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Carregando dados...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle("Resumo")
        .onAppear {
            analytics.track(.home_open)
            if let userId = authViewModel.user?.uid {
                viewModel.startListening(userId: userId)
                notificationsBadgeViewModel.startListening(userId: userId)
            }
            viewModel.setPreferredCurrencyCode(primaryCurrencyCodeRaw)
            viewModel.setProAccess(subscriptionManager.hasProAccess)
            pushPermissionState.refresh()
            evaluatePushPrompt()
            logScreenIfNeeded()
        }
        .onChange(of: viewModel.isLoading) { _, _ in
            logScreenIfNeeded()
        }
        .onChange(of: viewModel.hasSubscriptions) { _, _ in
            logScreenIfNeeded()
        }
        .onChange(of: viewModel.hasGroups) { _, _ in
            logScreenIfNeeded()
        }
        .onChange(of: pushPermissionState.status) { _, _ in
            evaluatePushPrompt()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                pushPermissionState.refresh()
            }
        }
        .onChange(of: authViewModel.user?.uid) { _, newValue in
            guard let userId = newValue else { return }
            viewModel.startListening(userId: userId)
            notificationsBadgeViewModel.startListening(userId: userId)
        }
        .onChange(of: primaryCurrencyCodeRaw) { _, newValue in
            viewModel.setPreferredCurrencyCode(newValue)
        }
        .onChange(of: subscriptionManager.hasProAccess) { _, newValue in
            viewModel.setProAccess(newValue)
        }
        .onDisappear {
            viewModel.stopListening()
            notificationsBadgeViewModel.stopListening()
            didLogScreen = false
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.push(.notificationsHistory, in: .home)
                } label: {
                    notificationBell
                }
                .accessibilityLabel("Notificações")
            }
        }
        .sheet(isPresented: $showPushPrompt) {
            PushPermissionView(
                onRequestDone: {
                    pushPermissionState.refresh()
                    showPushPrompt = false
                },
                onSkip: {
                    showPushPrompt = false
                }
            )
        }
    }

    private var summarySubtitle: String {
        if viewModel.hasMixedCurrencies {
            return "Total exibido na moeda principal"
        }
        return "Baseado nas assinaturas ativas"
    }

    private func logScreenIfNeeded() {
        guard !didLogScreen, !viewModel.isLoading else { return }
        if !viewModel.hasSubscriptions && !viewModel.hasGroups {
            analytics.screenView(.screen_home_empty)
        } else {
            analytics.screenView(.screen_home)
        }
        didLogScreen = true
    }

    private var summaryDetailItem: HomeInsightItem {
        let totalText = formattedCurrency(viewModel.totalMonthlyAmount, currencyCode: viewModel.currencyCode)
        var detail = "Este é o total mensal estimado de assinaturas e grupos. Total atual: \(totalText)."
        if viewModel.hasMixedCurrencies {
            detail += " Valores de outras moedas são convertidos para a moeda principal."
        }

        return HomeInsightItem(
            title: "Total mensal",
            icon: "info.circle",
            detail: detail,
            destination: nil
        )
    }

    private func formattedCurrency(_ value: Double, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "\(currencyCode) \(value)"
    }

    private var upcomingDestination: MainTab {
        if viewModel.hasSubscriptions {
            return .subscriptions
        }
        if viewModel.hasGroups {
            return .groups
        }
        return .subscriptions
    }

    private var notificationBell: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "bell")
                .font(.system(size: 18, weight: .semibold))

            if notificationsBadgeViewModel.unreadCount > 0 {
                Text(notificationBadgeText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .frame(minWidth: 16, minHeight: 16)
                    .background(
                        Capsule().fill(Color.red.opacity(1))
                    )
                    .offset(x: 3, y: -3)
            }
        }
    }

    private var notificationBadgeText: String {
        let count = notificationsBadgeViewModel.unreadCount
        return count > 9 ? "9+" : "\(count)"
    }

    private func evaluatePushPrompt() {
        guard pushPermissionState.status == .notDetermined || pushPermissionState.status == .denied else { return }
        let todayKey = DateFormatter.dayKeyFormatter.string(from: Date())
        guard lastPushPromptDateRaw != todayKey else { return }
        lastPushPromptDateRaw = todayKey
        showPushPrompt = true
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private extension DateFormatter {
    static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

#Preview {
    HomeView()
        .environmentObject(AppRouter())
}
