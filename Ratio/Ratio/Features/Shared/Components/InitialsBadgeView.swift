//
//  InitialsBadgeView.swift
//  Ratio
//
//  Created by Codex on 31/01/26.
//

import SwiftUI

struct InitialsBadgeView: View {
    let initials: String
    let backgroundColor: Color
    let foregroundColor: Color
    let size: CGFloat
    let cornerRadius: CGFloat

    init(
        initials: String,
        backgroundColor: Color,
        foregroundColor: Color,
        size: CGFloat = 42,
        cornerRadius: CGFloat = 12
    ) {
        self.initials = initials
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.size = size
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(backgroundColor)
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(foregroundColor)
            )
            .accessibilityHidden(true)
    }

    static func initials(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ").map(String.init)
        if parts.count >= 2 {
            let first = parts[0].prefix(1)
            let second = parts[1].prefix(1)
            return "\(first)\(second)".uppercased()
        }
        if let first = parts.first {
            return String(first.prefix(1)).uppercased()
        }
        return "?"
    }
}

#Preview {
    InitialsBadgeView(
        initials: InitialsBadgeView.initials(for: "Netflix Premium"),
        backgroundColor: Color(.secondarySystemBackground),
        foregroundColor: .primary
    )
    .padding()
}
