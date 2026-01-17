//
//  HomeCategoryLegendRowView.swift
//  Ratio
//
//  Created by Codex on 09/01/26.
//

import SwiftUI

struct HomeCategoryLegendRowView: View {
    let item: CategorySpendItem

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(item.color)
                .frame(width: 8, height: 8)

            Text(item.label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(formattedCurrency(item.amount, currencyCode: item.currencyCode))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }

    private func formattedCurrency(_ value: Double, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }
}
