//
//  SubscriptionPeriod.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import Foundation

enum SubscriptionPeriod: String, CaseIterable, Identifiable {
    case weekly
    case monthly
    case quarterly
    case yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weekly: return "Semanal"
        case .monthly: return "Mensal"
        case .quarterly: return "Trimestral"
        case .yearly: return "Anual"
        }
    }
}
