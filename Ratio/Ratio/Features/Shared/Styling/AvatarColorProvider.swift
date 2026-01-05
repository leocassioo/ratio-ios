//
//  AvatarColorProvider.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI

struct AvatarColorProvider {
    static func color(for name: String) -> Color {
        let colors: [Color] = [
            Color(uiColor: .systemBlue),
            Color(uiColor: .systemTeal),
            Color(uiColor: .systemGreen),
            Color(uiColor: .systemOrange),
            Color(uiColor: .systemPink),
            Color(uiColor: .systemPurple),
            Color(uiColor: .systemIndigo),
            Color(uiColor: .systemBrown)
        ]

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Color(uiColor: .systemGray4)
        }

        let index = abs(trimmed.hashValue) % colors.count
        return colors[index]
    }
}
