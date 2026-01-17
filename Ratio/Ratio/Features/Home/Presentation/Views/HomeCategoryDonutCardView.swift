//
//  HomeCategoryDonutCardView.swift
//  Ratio
//
//  Created by Codex on 09/01/26.
//

import SwiftUI

struct HomeCategoryDonutCardView: View {
    let items: [CategorySpendItem]
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var router: AppRouter
    @Environment(\.colorScheme) private var colorScheme

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
                ZStack {
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

                    if !subscriptionManager.hasProAccess {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial)
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

    private var cardBackground: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground)
    }

    private var borderOpacity: Double {
        colorScheme == .dark ? 0.4 : 0.25
    }
}
