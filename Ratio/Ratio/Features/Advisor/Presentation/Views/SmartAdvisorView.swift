//
//  SmartAdvisorView.swift
//  Ratio
//
//  Created by Codex on 15/02/26.
//

import SwiftUI
import FirebaseAuth

struct SmartAdvisorView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var router: AppRouter
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = SmartAdvisorViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !viewModel.hasRequestedAnalysis {
                    analysisCTA
                } else if viewModel.isLoading {
                    analyzingCard
                } else {
                    insightsCard
                }

                statsRow
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Smart Advisor")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    handleRefreshTap()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .onAppear {
            if let userId = authViewModel.user?.uid {
                viewModel.start(userId: userId)
            }
        }
    }

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Insights personalizados")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(insightsToDisplay) { insight in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• \(insight.title)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(insight.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text("* Insights gerados por IA. Sempre revise decisões financeiras.")
                .font(.footnote)
                .foregroundStyle(.secondary.opacity(0.7))
                .padding(.top, 8)

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(18)
        .background(cardBackground)
        .overlay(cardSymbolOverlay)
    }

    private var analysisCTA: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ative sua análise inteligente")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Descubra oportunidades de economia, assinaturas redundantes e dicas personalizadas para sua carteira.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                handleRefreshTap()
            } label: {
                Text("Gerar análise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(18)
        .background(cardBackground)
        .overlay(cardSymbolOverlay)
    }

    private var analyzingCard: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color(.systemIndigo))
                .scaleEffect(1.2)

            Text("Analisando padrões de gasto...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(cardBackground)
        .overlay(cardSymbolOverlay)
    }

    private var statsRow: some View {
        VStack(spacing: 12) {
            ForEach(statsToDisplay) { stat in
                statCard(
                    title: stat.title,
                    subtitle: stat.detail,
                    highlight: stat.isHighlighted
                )
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(.separator).opacity(borderOpacity), lineWidth: 1)
            )
    }

    private var cardSymbolOverlay: some View {
        Image(systemName: "brain.head.profile")
            .font(.system(size: 90))
            .foregroundStyle(Color(.secondaryLabel).opacity(0.2))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(10)
    }

    private func statCard(title: String, subtitle: String, highlight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(highlight ? Color(.systemGreen) : .primary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(.separator).opacity(borderOpacity), lineWidth: 1)
                )
        )
    }

    private var insightsToDisplay: [AdvisorInsight] {
        if viewModel.insights.isEmpty {
            return [
                AdvisorInsight(
                    id: UUID().uuidString,
                    title: "Aguarde os insights",
                    detail: "Atualize para receber análises personalizadas."
                )
            ]
        }
        return viewModel.insights
    }

    private var statsToDisplay: [AdvisorStat] {
        if viewModel.stats.isEmpty {
            return []
        }
        return viewModel.stats
    }

    private func handleRefreshTap() {
        guard subscriptionManager.isProUser else {
            router.present(.upgradePrompt(
                title: "Desbloqueie o Advisor inteligente",
                subtitle: "O Advisor com IA está disponível apenas no Ratio Pro.",
                benefits: [
                    "Insights personalizados sobre seus gastos",
                    "Sugestões de economia com IA",
                    "Relatórios avançados"
                ]
            ))
            return
        }
        viewModel.refreshInsights()
    }

    private var cardFill: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground)
    }

    private var borderOpacity: Double {
        colorScheme == .dark ? 0.4 : 0.25
    }
}

#Preview {
    SmartAdvisorView()
        .environmentObject(SubscriptionManager.shared)
        .environmentObject(AppRouter())
}
