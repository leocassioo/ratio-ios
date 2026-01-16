//
//  PasswordResetView.swift
//  Ratio
//
//  Created by Codex on 23/12/25.
//

import SwiftUI

struct PasswordResetView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var cooldownRemaining = 0
    @State private var cooldownTimer: Timer?

    var body: some View {
        VStack(spacing: 20) {
            Text("Recuperar senha")
                .font(.title2.bold())
            Text("Enviaremos um link para redefinir sua senha.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)
                .textFieldStyle(.roundedBorder)

            Button {
                guard cooldownRemaining == 0 else { return }
                authViewModel.sendPasswordReset(email: email)
                startCooldown()
            } label: {
                if authViewModel.isLoading {
                    ProgressView()
                } else {
                    Text(buttonTitle)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || authViewModel.isLoading || cooldownRemaining > 0)

            if authViewModel.passwordResetSent {
                Text("Email enviado. Verifique sua caixa de entrada.")
                    .font(.footnote)
                    .foregroundStyle(.green)
                    .multilineTextAlignment(.center)
            }

            if let message = authViewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Recuperar senha")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            authViewModel.errorMessage = nil
            authViewModel.passwordResetSent = false
        }
        .onDisappear {
            cooldownTimer?.invalidate()
            cooldownTimer = nil
        }
    }

    private var buttonTitle: String {
        if cooldownRemaining > 0 {
            return "Aguarde \(cooldownRemaining)s"
        }
        return "Enviar link"
    }

    private func startCooldown() {
        cooldownRemaining = 30
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if cooldownRemaining > 0 {
                cooldownRemaining -= 1
            } else {
                timer.invalidate()
            }
        }
    }
}

#Preview {
    NavigationStack {
        PasswordResetView()
            .environmentObject(AuthViewModel())
    }
}
