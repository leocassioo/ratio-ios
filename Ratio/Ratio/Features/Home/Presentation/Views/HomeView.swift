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
    @StateObject private var viewModel = HomeViewModel()
    @State private var hasUnreadNotifications = true
    @AppStorage(PreferencesStore.PrefKey.primaryCurrencyCode) private var primaryCurrencyCodeRaw: String = "BRL"
    private let upcomingPayments: [UpcomingPaymentItem] = [
        UpcomingPaymentItem(
            name: "SmartFit",
            initials: "S",
            amount: 119.90,
            currencyCode: "BRL",
            dueDate: Date().addingTimeInterval(2 * 24 * 60 * 60),
            period: "Mensal"
        ),
        UpcomingPaymentItem(
            name: "Netflix Premium",
            initials: "N",
            amount: 55.90,
            currencyCode: "BRL",
            dueDate: Date().addingTimeInterval(5 * 24 * 60 * 60),
            period: "Mensal"
        ),
        UpcomingPaymentItem(
            name: "Spotify Duo",
            initials: "S",
            amount: 27.90,
            currencyCode: "BRL",
            dueDate: Date().addingTimeInterval(12 * 24 * 60 * 60),
            period: "Mensal"
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
                        estimatedBRL: viewModel.estimatedBRL(forAmount: viewModel.totalMonthlyAmount, currencyCode: viewModel.currencyCode)
                    )

                        if !viewModel.isLoading && !viewModel.hasSubscriptions && !viewModel.hasGroups {
                            HomeEmptyStateView(
                                onAddSubscription: {
                                    router.route(to: .subscriptions)
                                },
                                onCreateGroup: {
                                    router.route(to: .groups)
                                }
                            )
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
                        HomeInsightsRowView(insights: viewModel.insights)
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
                        }
                    )

                    HomeCategoryDonutCardView(items: viewModel.categorySpends)

                    HomeMonthlySpendsCardView(
                        items: viewModel.monthlySpends,
                        currencyCode: viewModel.monthlySpendsCurrencyCode
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
            if let userId = authViewModel.user?.uid {
                viewModel.startListening(userId: userId)
            }
            viewModel.setPreferredCurrencyCode(primaryCurrencyCodeRaw)
            viewModel.setProAccess(subscriptionManager.hasProAccess)
        }
        .onChange(of: authViewModel.user?.uid) { _, newValue in
            guard let userId = newValue else { return }
            viewModel.startListening(userId: userId)
        }
        .onChange(of: primaryCurrencyCodeRaw) { _, newValue in
            viewModel.setPreferredCurrencyCode(newValue)
        }
        .onChange(of: subscriptionManager.hasProAccess) { _, newValue in
            viewModel.setProAccess(newValue)
        }
        .onDisappear {
            viewModel.stopListening()
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
    }

    private var summarySubtitle: String {
        if viewModel.hasMixedCurrencies {
            return "Total exibido na moeda principal"
        }
        return "Baseado nas assinaturas ativas"
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

            if hasUnreadNotifications {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .offset(x: 6, y: -4)
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppRouter())
}
