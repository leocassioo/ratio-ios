//
//  HomeUpcomingRowView.swift
//  Ratio
//
//  Created by Codex on 09/01/26.
//

import SwiftUI

struct HomeUpcomingRowView: View {
    let item: UpcomingPaymentItem
    let estimatedAmount: Double?
    let estimatedCurrencyCode: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            SubscriptionLogoView(
                subscriptionId: item.subscriptionId,
                initials: InitialsBadgeView.initials(for: item.name),
                backgroundColor: iconBackground,
                foregroundColor: iconForeground,
                size: 42,
                cornerRadius: 12
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                if let chip = UpcomingPaymentChipView.model(for: item.dueDate) {
                    HStack(spacing: 6) {
                        UpcomingPaymentChipView(text: chip.text, color: chip.color)
                        Text(formattedDate(item.dueDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(subtitleText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedCurrency(item.amount, currencyCode: item.currencyCode))
                    .font(.subheadline.weight(.semibold))
                if let estimatedAmount, let estimatedCurrencyCode, item.currencyCode != estimatedCurrencyCode {
                    Text("≈ \(formattedCurrency(estimatedAmount, currencyCode: estimatedCurrencyCode))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(item.period)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator).opacity(borderOpacity), lineWidth: 1)
        )
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground)
    }

    private var iconBackground: Color {
        let base = colorForCategory()
        return base.opacity(colorScheme == .dark ? 0.25 : 0.16)
    }

    private var iconForeground: Color {
        colorForCategory()
    }

    private func colorForCategory() -> Color {
        guard let category = item.category else {
            return Color(.systemPurple)
        }
        switch category {
        case .streaming:
            return Color(.systemIndigo)
        case .music:
            return Color(.systemPink)
        case .software:
            return Color(.systemTeal)
        case .housing:
            return Color(.systemOrange)
        case .utilities:
            return Color(.systemPurple)
        case .education:
            return Color(.systemBlue)
        case .fitness:
            return Color(.systemGreen)
        case .other:
            return Color(.systemGray)
        }
    }

    private var borderOpacity: Double {
        colorScheme == .dark ? 0.4 : 0.25
    }

    private var subtitleText: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dueDay = calendar.startOfDay(for: item.dueDate)
        let remaining = calendar.dateComponents([.day], from: today, to: dueDay).day ?? 0
        let formattedDate = formattedDate(item.dueDate)
        if remaining < 0 {
            return "Vencido • \(formattedDate)"
        }
        if remaining <= 7 {
            return formattedDate
        }
        return "\(remaining) dias • \(formattedDate)"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    private func formattedCurrency(_ value: Double, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }
}
