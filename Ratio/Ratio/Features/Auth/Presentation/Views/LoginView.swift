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
    @State private var isCreatingAccount = false

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
                        .textContentType(isCreatingAccount ? .newPassword : .password)
                        .submitLabel(.go)

                    Button(action: submit) {
                        if authViewModel.isLoading {
                            ProgressView()
                        } else {
                            Text(isCreatingAccount ? "Criar conta" : "Entrar")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(email.isEmpty || password.isEmpty || authViewModel.isLoading)

                    Button(isCreatingAccount ? "Já tenho conta" : "Criar nova conta") {
                        isCreatingAccount.toggle()
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
            .navigationTitle(isCreatingAccount ? "Criar conta" : "Entrar")
        }
    }

    private func submit() {
        if isCreatingAccount {
            authViewModel.signUp(email: email, password: password)
        } else {
            authViewModel.signIn(email: email, password: password)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
