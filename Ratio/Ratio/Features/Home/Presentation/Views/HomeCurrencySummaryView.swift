//
//  HomeCurrencySummaryView.swift
//  Ratio
//
//  Created by Codex on 09/01/26.
//

import SwiftUI

struct HomeCurrencySummaryView: View {
    let totalsByCurrency: [String: Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Totais por moeda")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(orderedTotals, id: \.code) { item in
                    HStack {
                        Text(item.code)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formattedCurrency(item.amount, currencyCode: item.code))
                            .font(.caption.weight(.semibold))
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator).opacity(0.2), lineWidth: 1)
        )
    }

    private var orderedTotals: [(code: String, amount: Double)] {
        totalsByCurrency
            .map { (code: $0.key, amount: $0.value) }
            .sorted { $0.code < $1.code }
    }

    private func formattedCurrency(_ value: Double, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "\(currencyCode) \(value)"
    }
}
