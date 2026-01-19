//
//  UpgradePromptView.swift
//  Ratio
//
//  Created by Codex on 23/12/25.
//

import SwiftUI

struct UpgradePromptView: View {
    let title: String
    let subtitle: String
    let benefits: [String]
    let onViewPlans: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.tint)
                        .padding(.top, 0)

                    Text(title)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(benefits, id: \.self) { benefit in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.body)
                                Text(benefit)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                }
                .padding([.leading, .trailing, .bottom], 20)
                .padding(.top, 0)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                    onViewPlans()
                } label: {
                    Text("Ver planos")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Ratio Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.75), .large])
    }
}

#Preview {
    UpgradePromptView(
        title: "Desbloqueie o Ratio Pro",
        subtitle: "Mais economia, lembretes inteligentes e insights avançados.",
        benefits: [
            "Grupos e assinaturas ilimitados",
            "Alertas de vencimento e cobrança avançados",
            "Análises inteligentes com IA",
            "Histórico completo com gráficos por categoria",
            "Estimativas automáticas de câmbio"
        ],
        onViewPlans: {}
    )
}
