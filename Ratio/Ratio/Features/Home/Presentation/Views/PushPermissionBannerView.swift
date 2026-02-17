//
//  PushPermissionBannerView.swift
//  Ratio
//
//  Created by Codex on 17/02/26.
//

import SwiftUI

struct PushPermissionBannerView: View {
    let status: PushPermissionState.Status
    let onPrimaryAction: () -> Void

    private var title: String {
        switch status {
        case .denied:
            return "Ative as notificações"
        case .notDetermined:
            return "Permita notificações importantes"
        case .authorized, .unknown:
            return "Notificações"
        }
    }

    private var subtitle: String {
        switch status {
        case .denied:
            return "Ative nos Ajustes para receber lembretes de cobrança."
        case .notDetermined:
            return "Receba avisos essenciais sobre cobranças e pagamentos."
        case .authorized, .unknown:
            return ""
        }
    }

    private var actionLabel: String {
        switch status {
        case .denied:
            return "Abrir Ajustes"
        case .notDetermined:
            return "Ativar"
        case .authorized, .unknown:
            return "Gerenciar"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "bell.badge")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.orange)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(actionLabel) {
                onPrimaryAction()
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.accentColor.opacity(0.12)))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator).opacity(0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
    }
}

#Preview {
    PushPermissionBannerView(status: .denied) {}
        .padding()
}
