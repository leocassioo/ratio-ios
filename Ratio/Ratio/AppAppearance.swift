//
//  AppAppearance.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import Foundation
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Seguir sistema"
        case .light: return "Claro"
        case .dark: return "Escuro"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case ptBR
    case en

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Seguir idioma do sistema"
        case .ptBR: return "Português (Brasil)"
        case .en: return "Inglês"
        }
    }

    var locale: Locale? {
        switch self {
        case .system:
            return nil
        case .ptBR:
            return Locale(identifier: "pt-BR")
        case .en:
            return Locale(identifier: "en")
        }
    }
}
