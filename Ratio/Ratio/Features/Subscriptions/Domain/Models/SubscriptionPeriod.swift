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
    case oneTime

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weekly: return "Semanal"
        case .monthly: return "Mensal"
        case .quarterly: return "Trimestral"
        case .yearly: return "Anual"
        case .oneTime: return "Única"
        }
    }

    static func from(label: String) -> SubscriptionPeriod? {
        switch label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "semanal": return .weekly
        case "mensal": return .monthly
        case "trimestral": return .quarterly
        case "anual": return .yearly
        case "única", "unica": return .oneTime
        default: return nil
        }
    }
}
