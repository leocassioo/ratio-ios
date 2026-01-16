//
//  PlanRowView.swift
//  Ratio
//
//  Created by Codex on 23/12/25.
//

import SwiftUI

struct PlanRowView: View {
    let title: String
    let detail: String
    let highlight: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(detail)
                        .font(.footnote)
                    if let highlight {
                        Text(highlight)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
