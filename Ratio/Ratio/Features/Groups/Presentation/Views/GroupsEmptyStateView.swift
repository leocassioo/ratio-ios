//
//  GroupsEmptyStateView.swift
//  Ratio
//
//  Created by Codex on 27/01/26.
//

import SwiftUI

struct GroupsEmptyStateView: View {
    let onAdd: () -> Void

    private let pages: [(title: String, subtitle: String, systemImage: String)] = [
        (
            title: "Divida custos com facilidade",
            subtitle: "Crie grupos para organizar rateios com amigos ou família.",
            systemImage: "person.3.fill"
        ),
        (
            title: "Convites simples",
            subtitle: "Compartilhe um link ou código para adicionar membros.",
            systemImage: "ticket"
        ),
        (
            title: "Sem assinatura também",
            subtitle: "Use para churrasco, viagens e outras despesas únicas.",
            systemImage: "sparkles"
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
                Label("Criar grupo", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)

            Text("Você pode editar ou remover grupos quando quiser.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

#Preview {
    GroupsEmptyStateView(onAdd: {})
}
