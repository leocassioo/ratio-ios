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
    case submitted
    case overdue
    case exempt

    var label: String {
        switch self {
        case .paid: return "Pago"
        case .pending: return "Pendente"
        case .submitted: return "Aguardando aprovação"
        case .overdue: return "Em atraso"
        case .exempt: return "Isento"
        }
    }

    static var editableCases: [GroupMemberStatus] {
        [.paid, .pending, .submitted, .overdue, .exempt]
    }
}
