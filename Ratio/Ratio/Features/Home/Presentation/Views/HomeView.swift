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
    @EnvironmentObject private var navigationState: AppNavigationState
    @StateObject private var viewModel = HomeViewModel()
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
        CategorySpendItem(label: "Streaming", amount: 132.80, color: Color(.systemIndigo)),
        CategorySpendItem(label: "Saúde", amount: 119.90, color: Color(.systemTeal)),
        CategorySpendItem(label: "Música", amount: 27.90, color: Color(.systemPink)),
        CategorySpendItem(label: "Outros", amount: 57.02, color: Color(.systemOrange))
    ]
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    HomeSummaryCardView(
                        totalAmount: viewModel.totalMonthlyAmount,
                        currencyCode: viewModel.currencyCode,
                        deltaText: summarySubtitle
                    )

                    if !viewModel.isLoading && !viewModel.hasSubscriptions && !viewModel.hasGroups {
                        HomeEmptyStateView(
                            onAddSubscription: {
                                navigationState.selectedTab = .subscriptions
                            },
                            onCreateGroup: {
                                navigationState.selectedTab = .groups
                            }
                        )
                    }
                    if viewModel.hasMixedCurrencies {
                        HomeCurrencySummaryView(totalsByCurrency: viewModel.totalsByCurrency)
                    }

                    if !viewModel.insights.isEmpty {
                        HomeInsightsRowView(insights: viewModel.insights)
                    }

                    HomeUpcomingSectionView(
                        items: viewModel.upcomingPayments,
                        destinationTab: upcomingDestination
                    )

                    HomeCategoryDonutCardView(items: viewModel.categorySpends)
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
        }
        .onChange(of: authViewModel.user?.uid) { _, newValue in
            guard let userId = newValue else { return }
            viewModel.startListening(userId: userId)
        }
        .onDisappear {
            viewModel.stopListening()
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
}

#Preview {
    HomeView()
        .environmentObject(AppNavigationState())
        .environmentObject(AppRouter())
}
