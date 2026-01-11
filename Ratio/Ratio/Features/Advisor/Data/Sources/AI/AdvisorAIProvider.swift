//
//  AdvisorAIProvider.swift
//  Ratio
//
//  Created by Codex on 15/02/26.
//

import Foundation

protocol AdvisorAIProvider {
    func generateInsights(context: String) async throws -> (insights: [AdvisorInsight], stats: [AdvisorStat])
}
