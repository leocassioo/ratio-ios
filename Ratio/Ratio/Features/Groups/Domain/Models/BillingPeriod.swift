//
//  BillingPeriod.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import Foundation

enum BillingPeriod: String, CaseIterable, Identifiable {
    case weekly = "semana"
    case monthly = "mês"
    case quarterly = "trimestre"
    case yearly = "ano"

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
