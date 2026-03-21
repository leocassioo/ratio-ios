//
//  SubscriptionStatus.swift
//  Ratio
//
//  Created by Codex on 20/03/26.
//

import Foundation

enum SubscriptionStatus: String, CaseIterable, Identifiable {
    case active
    case paused
    case canceled

    var id: String { rawValue }

    var label: String {
        switch self {
        case .active:
            return "Ativa"
        case .paused:
            return "Pausada"
        case .canceled:
            return "Cancelada"
        }
    }

    var isBillable: Bool {
        self == .active
    }
}
