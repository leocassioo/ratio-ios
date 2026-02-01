//
//  PasswordResetView.swift
//  Ratio
//
//  Created by Codex on 23/12/25.
//

import SwiftUI

struct PasswordResetView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showErrorAlert = false
    @State private var email = ""
    @State private var cooldownRemaining = 0
    @State private var cooldownTimer: Timer?
    private let analytics = AnalyticsService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Enviaremos um link para redefinir sua senha.")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 20) {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                        .submitLabel(.go)
                        .modifier(InputFieldStyle())

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
                    .controlSize(.large)
                    .disabled(!email.isValidEmail || authViewModel.isLoading || cooldownRemaining > 0)
                }
                .frame(maxWidth: 420)

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
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 32)
        }
        .navigationTitle("Recuperar senha")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            analytics.screenView(.screen_password_reset)
        }
        .onChange(of: authViewModel.errorMessage) { _, newValue in
            showErrorAlert = newValue != nil
        }
        .alert("Não foi possível enviar o link", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authViewModel.errorMessage ?? "")
        }
        .onAppear {
            authViewModel.errorMessage = nil
            authViewModel.passwordResetSent = false
        }
        .onDisappear {
            cooldownTimer?.invalidate()
            cooldownTimer = nil
        }
    }

    private struct InputFieldStyle: ViewModifier {
        func body(content: Content) -> some View {
            content
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(.separator).opacity(0.6), lineWidth: 1)
                )
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
