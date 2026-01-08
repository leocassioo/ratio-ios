//
//  InviteError.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import Foundation

enum InviteError: LocalizedError {
    case invalid
    case expired
    case alreadyUsed
    case alreadyMember

    var errorDescription: String? {
        switch self {
        case .invalid:
            return "Convite inválido."
        case .expired:
            return "Convite expirado."
        case .alreadyUsed:
            return "Este convite já foi utilizado."
        case .alreadyMember:
            return "Você já faz parte deste grupo."
        }
    }
}
