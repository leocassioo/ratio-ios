//
//  LoginView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var router: AppRouter
    @AppStorage(PreferencesStore.PrefKey.pendingEmailChangeNotice) private var showEmailChangeNotice = false
    @State private var email = ""
    @State private var password = ""

    var body: some View {
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
                    router.pushAuth(.passwordReset)
                }
                .font(.footnote)

                Button("Criar nova conta") {
                    router.pushAuth(.signup)
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

            if showEmailChangeNotice {
                VStack(spacing: 8) {
                    Text("Email alterado: confirme no link enviado e faça login novamente.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Ok, entendi") {
                        showEmailChangeNotice = false
                    }
                    .font(.footnote.weight(.semibold))
                }
                .frame(maxWidth: 420)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Entrar")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() {
        authViewModel.signIn(email: email, password: password)
    }

    private var isSubmitDisabled: Bool {
        authViewModel.isLoading || email.isEmpty || password.isEmpty
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(AuthViewModel())
            .environmentObject(AppRouter())
    }
}
