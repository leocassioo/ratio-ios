//
//  HomeInsightDetailSheetView.swift
//  Ratio
//
//  Created by Codex on 27/01/26.
//

import SwiftUI

struct HomeInsightDetailSheetView: View {
    let item: HomeInsightItem
    let onOpen: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    private let analytics = AnalyticsService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: item.icon)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Color(.systemIndigo))
                        .padding(16)
                        .background(
                            Circle()
                                .fill(Color(.secondarySystemBackground))
                        )

                    Text(item.title)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)

                    Text(item.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 420)
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .safeAreaInset(edge: .bottom) {
                if let onOpen {
                    VStack {
                        Button {
                            onOpen()
                            dismiss()
                        } label: {
                            Text(actionTitle)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("Detalhes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear {
            analytics.screenView(.screen_home_insight_detail)
        }
    }

    private var actionTitle: String {
        switch item.destination {
        case .subscriptions:
            return "Abrir assinaturas"
        case .groups:
            return "Abrir grupos"
        case .advisor:
            return "Abrir advisor"
        case .settings:
            return "Abrir ajustes"
        case .home:
            return "Abrir resumo"
        case .none:
            return "Abrir"
        }
    }
}

#Preview {
    HomeInsightDetailSheetView(
        item: HomeInsightItem(
            title: "2 cobranças hoje",
            icon: "bell.badge",
            detail: "Há 2 cobranças vencendo hoje. Revise seus pagamentos.",
            destination: .groups
        ),
        onOpen: {}
    )
}
