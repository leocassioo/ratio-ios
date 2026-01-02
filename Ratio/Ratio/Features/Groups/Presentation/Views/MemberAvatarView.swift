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
        Text(initials(from: name))
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color(.label))
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(Color(.systemGray5))
            )
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let second = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + second).uppercased()
    }
}
