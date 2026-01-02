//
//  LoginView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showResetSheet = false
    @State private var resetEmail = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Ratio")
                        .font(.largeTitle.bold())
                    Text("Entre para gerenciar suas assinaturas.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                        .submitLabel(.next)

                    SecureField("Senha", text: $password)
                        .textContentType(.password)
                        .submitLabel(.go)

                    Button(action: submit) {
                        if authViewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Entrar")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitDisabled)

                    Button("Esqueci minha senha") {
                        resetEmail = email
                        authViewModel.errorMessage = nil
                        authViewModel.passwordResetSent = false
                        showResetSheet = true
                    }
                    .font(.footnote)

                    NavigationLink("Criar nova conta") {
                        SignupView()
                    }
                    .font(.footnote)
                }
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 420)

                if let message = authViewModel.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Entrar")
        }
        .sheet(isPresented: $showResetSheet) {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Recuperar senha")
                        .font(.title2.bold())
                    Text("Enviaremos um link para redefinir sua senha.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    TextField("Email", text: $resetEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        authViewModel.sendPasswordReset(email: resetEmail)
                    } label: {
                        if authViewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Enviar link")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(resetEmail.isEmpty || authViewModel.isLoading)

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
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fechar") {
                            showResetSheet = false
                        }
                    }
                }
            }
            .onDisappear {
                authViewModel.errorMessage = nil
                authViewModel.passwordResetSent = false
            }
        }
    }

    private func submit() {
        authViewModel.signIn(email: email, password: password)
    }

    private var isSubmitDisabled: Bool {
        authViewModel.isLoading || email.isEmpty || password.isEmpty
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
