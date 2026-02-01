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
    let categoryBreakdown: [CategorySpendItem]
    let currencyCode: String
    let onMonthTap: ((Int) -> Void)?
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Evolução mensal")
                    .font(.headline)
                Spacer()
                if hasData, subscriptionManager.hasProAccess {
                    Text("Total: \(formattedCurrency(totalAmount))")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if !hasData {
                emptyStateView
            } else {
                chartView
                if subscriptionManager.hasProAccess {
                    monthlyLegend
                }
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
            ForEach(chartSegments) { segment in
                BarMark(
                    x: .value("Mês", segment.monthLabel),
                    y: .value("Total", segment.amount),
                    stacking: .standard
                )
                .foregroundStyle(segment.color)
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
                router.present(.subscriptionBenefits(source: .charts))
            }
        }

    private var monthlyLegend: some View {
        VStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                Button {
                    onMonthTap?(index)
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(.systemGray4))
                            .frame(width: 6, height: 6)

                        Text(item.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(formattedCurrency(item.amount))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
            }
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

    private var totalAmount: Double {
        items.reduce(0) { $0 + $1.amount }
    }

    private var chartSegments: [MonthlySpendSegment] {
        guard hasData else { return [] }

        var segments: [MonthlySpendSegment] = []
        let shares = categoryShares

        for (index, item) in items.enumerated() {
            guard item.amount > 0, !shares.isEmpty else {
                segments.append(
                    MonthlySpendSegment(
                        monthLabel: item.label,
                        amount: item.amount,
                        color: monthlyColor(for: index)
                    )
                )
                continue
            }

            let target = item.amount
            var allocated = 0.0
            for share in shares {
                let value = target * share.share
                allocated += value
                segments.append(
                    MonthlySpendSegment(
                        monthLabel: item.label,
                        amount: value,
                        color: share.color
                    )
                )
            }

            let remainder = max(0, target - allocated)
            if remainder > 0.01 {
                segments.append(
                    MonthlySpendSegment(
                        monthLabel: item.label,
                        amount: remainder,
                        color: Color(.systemGray4)
                    )
                )
            }
        }

        return segments
    }

    private var categoryShares: [(color: Color, share: Double)] {
        let total = categoryBreakdown.reduce(0) { $0 + max(0, $1.amount) }
        guard total > 0 else { return [] }
        return categoryBreakdown
            .filter { $0.amount > 0 }
            .map { item in
                (color: item.color, share: item.amount / total)
            }
    }

    private func monthlyColor(for index: Int) -> Color {
        let steps: [Double] = colorScheme == .dark
            ? [0.35, 0.45, 0.55, 0.65, 0.75, 0.85]
            : [0.85, 0.75, 0.65, 0.55, 0.45, 0.35]

        return Color.accentColor.opacity(steps[index % steps.count])
    }

    private func formattedCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "\(currencyCode) \(value)"
    }
}

private struct MonthlySpendSegment: Identifiable {
    let id = UUID()
    let monthLabel: String
    let amount: Double
    let color: Color
}
