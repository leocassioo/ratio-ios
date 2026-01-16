//
//  SubscriptionSuccessView.swift
//  Ratio
//
//  Created by Codex on 23/12/25.
//

import SwiftUI

struct SubscriptionSuccessView: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Assinatura ativa!")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            Text("O Ratio Pro está ativo. Aproveite análises inteligentes e controle total das suas assinaturas.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: onDone) {
                Text("Continuar")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .padding()
    }
}
