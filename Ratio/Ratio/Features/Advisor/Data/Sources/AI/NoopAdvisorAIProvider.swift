//
//  NoopAdvisorAIProvider.swift
//  Ratio
//
//  Created by Codex on 15/02/26.
//

import Foundation

final class NoopAdvisorAIProvider: AdvisorAIProvider {
    func generateInsights(context: String) async throws -> AdvisorAIResult {
        AdvisorAIResult(
            insights: [
                AdvisorInsight(
                    id: UUID().uuidString,
                    title: "Adicione suas assinaturas",
                    detail: "Inclua mais serviços para gerar insights mais completos."
                ),
                AdvisorInsight(
                    id: UUID().uuidString,
                    title: "Compartilhe com seu grupo",
                    detail: "Convide amigos para dividir assinaturas e reduzir custos."
                ),
                AdvisorInsight(
                    id: UUID().uuidString,
                    title: "Acompanhe vencimentos",
                    detail: "Use os lembretes para evitar atrasos em cobranças."
                )
            ],
            stats: [
                AdvisorStat(
                    id: UUID().uuidString,
                    title: "Top 10%",
                    detail: "Você gasta menos em streaming que 90% dos usuários.",
                    isHighlighted: false
                ),
                AdvisorStat(
                    id: UUID().uuidString,
                    title: "R$ 45,00",
                    detail: "Economia potencial mensal identificada.",
                    isHighlighted: true
                )
            ],
            tokenUsage: nil
        )
    }
}
