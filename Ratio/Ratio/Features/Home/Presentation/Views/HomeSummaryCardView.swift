//
//  HomeSummaryCardView.swift
//  Ratio
//
//  Created by Codex on 09/01/26.
//

import SwiftUI

struct HomeSummaryCardView: View {
    let totalAmount: Double
    let currencyCode: String
    let deltaText: String

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Total mensal")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))

                Text(formattedCurrency(totalAmount, currencyCode: currencyCode))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)

                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                    Text(deltaText)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                )
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "creditcard.fill")
                .font(.system(size: 54))
                .foregroundStyle(Color.white.opacity(0.18))
                .padding(16)
        }
        .background(
            LinearGradient(
                colors: [Color(.systemIndigo), Color(.systemBlue)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 16, x: 0, y: 10)
    }

    private func formattedCurrency(_ value: Double, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }
}
