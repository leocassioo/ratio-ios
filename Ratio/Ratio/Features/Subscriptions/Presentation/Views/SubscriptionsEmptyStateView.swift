//
//  SubscriptionsEmptyStateView.swift
//  Ratio
//
//  Created by Codex on 27/01/26.
//

import SwiftUI

struct SubscriptionsEmptyStateView: View {
    let onAdd: () -> Void

    private let pages: [(title: String, subtitle: String, systemImage: String)] = [
        (
            title: "Seu gestor de assinaturas",
            subtitle: "Controle tudo em um só lugar, sem conexão com seu banco nem cartão de crédito.",
            systemImage: "tray.full"
        ),
        (
            title: "Privacidade em primeiro lugar",
            subtitle: "Não cobramos dados financeiros nem pedimos acesso ao seu cartão.",
            systemImage: "lock.shield"
        ),
        (
            title: "Organize e compartilhe",
            subtitle: "Crie grupos e divida custos quando fizer sentido.",
            systemImage: "person.3"
        )
    ]

    var body: some View {
        VStack(spacing: 16) {
            TabView {
                ForEach(Array(pages.enumerated()), id: \.offset) { _, page in
                    VStack(spacing: 12) {
                        Image(systemName: page.systemImage)
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text(page.title)
                            .font(.headline)
                        Text(page.subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 270)
                            .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .frame(height: 200)
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .tint(.primary)

            Button(action: onAdd) {
                Label("Adicionar assinatura", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)

            Text("Você pode editar ou remover quando quiser.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

#Preview {
    SubscriptionsEmptyStateView(onAdd: {})
}
