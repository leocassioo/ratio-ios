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
            Text(item.initials)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(iconForeground)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(iconBackground)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        colorScheme == .dark ? Color(.tertiarySystemBackground) : Color(.secondarySystemBackground)
    }

    private var iconForeground: Color {
        colorScheme == .dark ? .white : .primary
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
        if remaining == 0 {
            return "Hoje • \(formattedDate)"
        }
        if remaining == 1 {
            return "Amanhã • \(formattedDate)"
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
