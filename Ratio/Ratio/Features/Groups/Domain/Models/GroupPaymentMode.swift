//
//  GroupPaymentMode.swift
//  Ratio
//
//  Created by Codex on 15/02/26.
//

import Foundation

enum GroupPaymentMode: String, CaseIterable, Identifiable {
    case split
    case rotation

    var id: String { rawValue }

    var label: String {
        switch self {
        case .split:
            return "Divisão"
        case .rotation:
            return "Rodízio"
        }
    }
}
