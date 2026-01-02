//
//  GroupCategory.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import Foundation

enum GroupCategory: String, CaseIterable, Identifiable {
    case streaming
    case software
    case housing
    case utilities
    case education
    case fitness
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .streaming: return "Streaming"
        case .software: return "Software"
        case .housing: return "Moradia"
        case .utilities: return "Serviços"
        case .education: return "Educação"
        case .fitness: return "Fitness"
        case .other: return "Outros"
        }
    }
}
