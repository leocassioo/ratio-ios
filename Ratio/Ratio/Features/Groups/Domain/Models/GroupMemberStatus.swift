//
//  GroupMemberStatus.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import Foundation

enum GroupMemberStatus: String, CaseIterable {
    case paid
    case pending

    var label: String {
        switch self {
        case .paid: return "Pago"
        case .pending: return "Pendente"
        }
    }
}
