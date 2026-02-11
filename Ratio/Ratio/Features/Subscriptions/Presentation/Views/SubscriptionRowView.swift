//
//  SubscriptionRowView.swift
//  Ratio
//
//  Created by Codex on 31/01/26.
//

import SwiftUI

struct SubscriptionRowView: View {
    let subscription: SubscriptionItem
    let estimatedAmount: Double?
    let preferredCurrencyCode: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            SubscriptionLogoView(
                subscriptionId: subscription.id,
                logoURL: subscription.logoURL.flatMap(URL.init),
                initials: InitialsBadgeView.initials(for: subscription.name),
                backgroundColor: iconBackground,
                foregroundColor: iconForeground,
                size: 42,
                cornerRadius: 12
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(subscription.name)
                    .font(.subheadline.weight(.semibold))

                Text("\(subscription.period.label) • \(subscription.category.label)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Text("Próxima cobrança: \(formattedDate(subscription.nextBillingDate))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    if let chip = SubscriptionRenewalChipView.model(for: subscription) {
                        SubscriptionRenewalChipView(text: chip.text, color: chip.color)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedCurrency(subscription.amount, currencyCode: subscription.currencyCode))
                    .font(.subheadline.weight(.semibold))

                if let estimatedAmount, subscription.currencyCode != preferredCurrencyCode {
                    Text("≈ \(formattedCurrency(estimatedAmount, currencyCode: preferredCurrencyCode))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
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

    private var iconBackground: Color {
        let base = colorForCategory()
        return base.opacity(colorScheme == .dark ? 0.25 : 0.16)
    }

    private var iconForeground: Color {
        colorForCategory()
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground)
    }

    private var borderOpacity: Double {
        colorScheme == .dark ? 0.4 : 0.25
    }

    private func colorForCategory() -> Color {
        switch subscription.category {
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

    private func formattedCurrency(_ value: Double, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "\(currencyCode) \(value)"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: date)
    }
}

#Preview {
    SubscriptionRowView(
        subscription: SubscriptionItem(
            id: "1",
            name: "Netflix",
            amount: 55.9,
            currencyCode: "BRL",
            category: .streaming,
            period: .monthly,
            nextBillingDate: Date(),
            notes: "",
            logoURL: nil
        ),
        estimatedAmount: nil,
        preferredCurrencyCode: "BRL"
    )
    .padding()
}
