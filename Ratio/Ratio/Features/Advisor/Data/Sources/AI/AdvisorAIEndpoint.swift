//
//  AdvisorAIEndpoint.swift
//  Ratio
//
//  Created by Codex on 15/02/26.
//

import Foundation

enum AdvisorAIEndpoint {
    case chatCompletions

    var url: URL? {
        switch self {
        case .chatCompletions:
            return URL(string: "https://api.openai.com/v1/chat/completions")
        }
    }
}
