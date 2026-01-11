//
//  HomeInsightChipView.swift
//  Ratio
//
//  Created by Codex on 09/01/26.
//

import SwiftUI

struct HomeInsightChipView: View {
    let item: HomeInsightItem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(.systemIndigo))
            Text(item.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            Capsule()
                .stroke(Color(.separator).opacity(0.2), lineWidth: 1)
        )
    }
}
