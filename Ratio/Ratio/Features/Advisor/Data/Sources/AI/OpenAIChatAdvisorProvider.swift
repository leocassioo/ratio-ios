//
//  OpenAIChatAdvisorProvider.swift
//  Ratio
//
//  Created by Codex on 15/02/26.
//

import Foundation

final class OpenAIChatAdvisorProvider: AdvisorAIProvider {
    private let requestBuilder: AdvisorAIRequestBuilder

    init(apiKey: String, session: URLSession = .shared) {
        self.requestBuilder = AdvisorAIRequestBuilder(apiKey: apiKey, session: session)
    }

    func generateInsights(context: String) async throws -> (insights: [AdvisorInsight], stats: [AdvisorStat]) {
        let prompt = """
        Você é um consultor financeiro pessoal. Use o contexto abaixo para gerar insights úteis sobre assinaturas.

        Contexto (JSON):
        \(context)

        Responda SOMENTE com JSON válido no formato:
        {
          "insights": [
            {"title": "...", "detail": "..."},
            {"title": "...", "detail": "..."}
          ],
          "stats": [
            {"title": "...", "detail": "...", "highlight": false},
            {"title": "...", "detail": "...", "highlight": true}
          ]
        }

        Regras:
        - Use português do Brasil.
        - Gere 3 insights e 2 stats.
        - Seja direto e com dicas acionáveis.
        - NÃO sugira "trocar para plano anual" se a assinatura já for anual (period == "yearly").
        - Só sugira plano anual se a assinatura for mensal ou semanal.
        - Não inclua texto fora do JSON.
        """

        let body: [String: Any] = [
            "model": "gpt-5-nano-2025-08-07",
            "messages": [
                ["role": "system", "content": "Você responde apenas com JSON válido."],
                ["role": "user", "content": prompt]
            ],
            "reasoning_effort": "low",
            "max_completion_tokens": 5000
        ]

        let request = try requestBuilder.makeRequest(.chatCompletions, body: body)
        let content = try await requestBuilder.perform(request)
        return parseInsights(from: content)
    }

    private func parseInsights(from content: String) -> (insights: [AdvisorInsight], stats: [AdvisorStat]) {
        guard let data = sanitizedJSON(from: content)?.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (defaultInsights(), defaultStats())
        }

        let insights = parseInsights(from: object["insights"])
        let stats = parseStats(from: object["stats"])
        return (insights.isEmpty ? defaultInsights() : insights, stats.isEmpty ? defaultStats() : stats)
    }

    private func sanitizedJSON(from content: String) -> String? {
        guard let start = content.firstIndex(of: "{"),
              let end = content.lastIndex(of: "}") else {
            return nil
        }
        return String(content[start...end])
    }

    private func parseInsights(from value: Any?) -> [AdvisorInsight] {
        guard let items = value as? [[String: Any]] else { return [] }
        return items.compactMap { dict in
            guard let title = dict["title"] as? String,
                  let detail = dict["detail"] as? String else {
                return nil
            }
            return AdvisorInsight(id: UUID().uuidString, title: title, detail: detail)
        }
    }

    private func parseStats(from value: Any?) -> [AdvisorStat] {
        guard let items = value as? [[String: Any]] else { return [] }
        return items.compactMap { dict in
            guard let title = dict["title"] as? String,
                  let detail = dict["detail"] as? String else {
                return nil
            }
            let highlight = dict["highlight"] as? Bool ?? false
            return AdvisorStat(id: UUID().uuidString, title: title, detail: detail, isHighlighted: highlight)
        }
    }

    private func defaultInsights() -> [AdvisorInsight] {
        [
            AdvisorInsight(
                id: UUID().uuidString,
                title: "Compartilhe assinaturas para reduzir custos",
                detail: "Algumas assinaturas podem ser divididas com o grupo para diminuir o valor por pessoa."
            ),
            AdvisorInsight(
                id: UUID().uuidString,
                title: "Priorize seus maiores gastos recorrentes",
                detail: "Revise as assinaturas mais caras e veja se existem planos anuais com desconto."
            ),
            AdvisorInsight(
                id: UUID().uuidString,
                title: "Evite serviços redundantes",
                detail: "Se você tem vários serviços da mesma categoria, avalie pausar algum deles."
            )
        ]
    }

    private func defaultStats() -> [AdvisorStat] {
        [
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
        ]
    }
}
