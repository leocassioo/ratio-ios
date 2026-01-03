//
//  MemberAvatarView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI

struct MemberAvatarView: View {
    let name: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray5))
                .overlay(
                    Circle()
                        .stroke(Color(.separator).opacity(0.4), lineWidth: 0.5)
                )

            if let initials = initials(from: name), !initials.isEmpty {
                Text(initials)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(.label))
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
        .frame(width: 36, height: 36)
    }

    private func initials(from name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let second = parts.dropFirst().first?.first.map(String.init) ?? ""
        let value = (first + second).uppercased()
        return value.isEmpty ? nil : value
    }
}
