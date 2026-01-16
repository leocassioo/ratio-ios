//
//  HomeCategoryDonutCardView.swift
//  Ratio
//
//  Created by Codex on 09/01/26.
//

import SwiftUI

struct HomeCategoryDonutCardView: View {
    let items: [CategorySpendItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Gastos por categoria")
                .font(.headline)

            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Sem dados ainda")
                        .font(.subheadline.weight(.semibold))
                    Text("Adicione assinaturas para ver os gastos por categoria.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                HStack(spacing: 16) {
                    HomeCategoryDonutView(items: items)
                        .frame(width: 140, height: 140)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(items) { item in
                            HomeCategoryLegendRowView(item: item)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.separator).opacity(0.2), lineWidth: 1)
        )
    }
}
