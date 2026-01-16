//
//  HomeEmptyStateView.swift
//  Ratio
//
//  Created by Codex on 23/12/25.
//

import SwiftUI

struct HomeEmptyStateView: View {
    let onAddSubscription: () -> Void
    let onCreateGroup: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(.tint)

            Text("Comece pelo essencial")
                .font(.headline)

            Text("Adicione sua primeira assinatura ou crie um grupo para dividir custos.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            VStack(spacing: 12) {
                Button(action: onAddSubscription) {
                    Text("Adicionar assinatura")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .frame(height: 44)

                Button(action: onCreateGroup) {
                    Text("Criar grupo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .frame(height: 44)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(.separator), lineWidth: 1)
                )
        )
    }
}
