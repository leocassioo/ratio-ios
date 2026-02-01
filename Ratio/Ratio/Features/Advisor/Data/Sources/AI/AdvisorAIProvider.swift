//
//  AdvisorAIProvider.swift
//  Ratio
//
//  Created by Codex on 15/02/26.
//

import Foundation

struct AdvisorAIResult {
    let insights: [AdvisorInsight]
    let stats: [AdvisorStat]
    let tokenUsage: Int?
}

protocol AdvisorAIProvider {
    func generateInsights(context: String) async throws -> AdvisorAIResult
}
