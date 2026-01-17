//
//  SubscriptionProduct.swift
//  Ratio
//
//  Created by Codex on 23/12/25.
//

import Foundation

enum SubscriptionProduct: String, CaseIterable, Identifiable {
    case monthly = "ratio_pro_monthly"
    case semiannual = "ratio_pro_semiannual"
    case annual = "ratio_pro_annual"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .monthly:
            return "Plano mensal"
        case .semiannual:
            return "Plano semestral"
        case .annual:
            return "Plano anual"
        }
    }

    var trialDays: Int? {
        switch self {
        case .monthly:
            return 3
        case .semiannual:
            return 7
        case .annual:
            return 14
        }
    }

    var promotionalBadge: String? {
        switch self {
        case .monthly, .semiannual:
            return nil
        case .annual:
            return "Economize"
        }
    }

    var displayOrder: Int {
        switch self {
        case .annual: return 1
        case .semiannual: return 2
        case .monthly: return 3
        }
    }
}
