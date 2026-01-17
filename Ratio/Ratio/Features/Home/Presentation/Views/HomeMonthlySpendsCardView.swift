//
//  HomeMonthlySpendsCardView.swift
//  Ratio
//
//  Created by Codex on 20/02/26.
//

import Charts
import SwiftUI

struct HomeMonthlySpendsCardView: View {
    let items: [MonthlySpendItem]
    let currencyCode: String
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Evolução mensal")
                .font(.headline)

            if !hasData {
                emptyStateView
            } else {
                chartView
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.separator).opacity(borderOpacity), lineWidth: 1)
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Sem histórico mensal")
                .font(.subheadline.weight(.semibold))
            Text("As cobranças registradas aparecerão aqui.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
    }

    private var chartView: some View {
        ZStack {
            chartContent
                .zIndex(0)
            if !subscriptionManager.hasProAccess {
                paywallOverlay
                    .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var chartContent: some View {
        Group {
            if subscriptionManager.hasProAccess {
                chartBase
            } else {
                chartBase
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var chartBase: some View {
        Chart {
            ForEach(items) { item in
                BarMark(
                    x: .value("Mês", item.label),
                    y: .value("Total", item.amount)
                )
                .foregroundStyle(Color(.systemIndigo))
                .cornerRadius(4)
            }
        }
        .frame(height: 180)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(formattedCurrency(amount))
                    }
                }
                .offset(x: 6)
            }
        }
    }

    private var paywallOverlay: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.ultraThinMaterial)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                VStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.title3)
                    Text("Disponível no Ratio Pro")
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(.secondary)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onTapGesture {
                router.present(.subscriptionBenefits)
            }
    }

    private var hasData: Bool {
        items.contains { $0.amount > 0 }
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground)
    }

    private var borderOpacity: Double {
        colorScheme == .dark ? 0.4 : 0.25
    }

    private func formattedCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "\(currencyCode) \(value)"
    }
}
