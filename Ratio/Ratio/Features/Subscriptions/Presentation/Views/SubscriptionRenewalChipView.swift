//
//  SubscriptionRenewalChipView.swift
//  Ratio
//
//  Created by Codex on 31/01/26.
//

import SwiftUI

struct SubscriptionRenewalChipView: View {
    struct Model {
        let text: String
        let color: Color
    }

    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.16))
            )
            .accessibilityLabel(Text(text))
    }

    static func model(
        for subscription: SubscriptionItem,
        calendar: Calendar = .current,
        today: Date = Date()
    ) -> Model? {
        let startOfToday = calendar.startOfDay(for: today)
        let targetDate = calendar.startOfDay(for: subscription.nextBillingDate)
        let daysRemaining = calendar.dateComponents([.day], from: startOfToday, to: targetDate).day ?? 0

        guard daysRemaining <= 7 else { return nil }

        let text: String
        if daysRemaining <= 0 {
            text = "Hoje"
        } else if daysRemaining == 1 {
            text = "Amanhã"
        } else {
            text = "\(daysRemaining) dias"
        }

        let color: Color
        switch daysRemaining {
        case ...0:
            color = .red
        case 1:
            color = .orange
        case 2...3:
            color = Color(.systemYellow)
        default:
            color = .blue
        }

        return Model(text: text, color: color)
    }
}

#Preview {
    SubscriptionRenewalChipView(text: "Renova em 3 dias", color: .blue)
}
