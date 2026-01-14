//
//  BillingHistoryType.swift
//  Ratio
//
//  Created by Codex on 16/02/26.
//

import Foundation

enum BillingHistoryType: String {
    case subscription
    case group

    var label: String {
        switch self {
        case .subscription:
            return "Assinatura"
        case .group:
            return "Grupo"
        }
    }
}
