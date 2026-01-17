//
//  PrimaryCurrencyOption.swift
//  Ratio
//
//  Created by Codex on 20/02/26.
//

import Foundation

enum PrimaryCurrencyOption: String, CaseIterable, Identifiable {
    case brl = "BRL"
    case usd = "USD"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .brl:
            return "Real (BRL)"
        case .usd:
            return "Dólar (USD)"
        }
    }

    static func from(code: String?) -> PrimaryCurrencyOption {
        guard let code, let option = PrimaryCurrencyOption(rawValue: code) else {
            return .brl
        }
        return option
    }
}
