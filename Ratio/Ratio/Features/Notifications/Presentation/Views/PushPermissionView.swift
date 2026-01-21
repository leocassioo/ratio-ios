//
//  PushPermissionView.swift
//  Ratio
//
//  Created by Codex on 23/12/25.
//

import SwiftUI
import UIKit

struct PushPermissionView: View {
    let onRequestDone: () -> Void
    let onSkip: () -> Void
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.badge.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundStyle(.tint)

            Text("Receba lembretes importantes")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            Text("Usamos notificações apenas para avisos essenciais do app, como lembretes de cobrança e confirmações de pagamento.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                Button {
                    isRequesting = true
                    UNUserNotificationCenter.current().getNotificationSettings { settings in
                        DispatchQueue.main.async {
                            if settings.authorizationStatus == .denied {
                                isRequesting = false
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                                onRequestDone()
                                return
                            }

                            NotificationManager.shared.requestAuthorization { _ in
                                isRequesting = false
                                onRequestDone()
                            }
                        }
                    }
                } label: {
                    Text(isRequesting ? "Ativando..." : "Ativar notificações")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundColor(.white)
                }
                .disabled(isRequesting)

                Button {
                    onSkip()
                } label: {
                    Text("Agora não")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding()
    }
}
