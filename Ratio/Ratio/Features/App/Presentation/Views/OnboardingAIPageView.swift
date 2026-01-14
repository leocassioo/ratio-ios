//
//  OnboardingAIPageView.swift
//  Ratio
//
//  Created by Codex on 23/12/25.
//

import SwiftUI

struct OnboardingAIPageView: View {
    let systemImage: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: systemImage)
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundStyle(.tint)

            Text(title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(description)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            OnboardingHighlightCardView(
                title: "Análises inteligentes com IA",
                subtitle: "Descubra padrões de gastos e sugestões para economizar."
            )
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding()
    }
}
