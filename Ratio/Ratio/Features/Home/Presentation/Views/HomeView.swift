//
//  HomeView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI

struct HomeView: View {
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
    private let insights: [HomeInsightItem] = [
        HomeInsightItem(title: "2 assinaturas sem grupo", icon: "person.3"),
        HomeInsightItem(title: "1 cobrança hoje", icon: "bell.badge"),
        HomeInsightItem(title: "R$ 48,00 economizados", icon: "leaf")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HomeSummaryCardView(
                        totalAmount: 337.62,
                        currencyCode: "BRL",
                        deltaText: "+2,5% desde o último mês"
                    )

                    HomeInsightsRowView(insights: insights)

                    HomeUpcomingSectionView(items: upcomingPayments)

                    HomeCategoryDonutCardView(items: categorySpends)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Resumo")
        }
    }
}

#Preview {
    HomeView()
}
