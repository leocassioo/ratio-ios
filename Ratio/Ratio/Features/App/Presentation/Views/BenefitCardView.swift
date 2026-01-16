//
//  BenefitCardView.swift
//  Ratio
//
//  Created by Codex on 23/12/25.
//

import SwiftUI

struct BenefitCardView: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.primary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }
}
