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
        VStack(spacing: 32) {
            header

            VStack(spacing: 20) {
                Spacer()
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                    .submitLabel(.next)
                    .modifier(InputFieldStyle())

                SecureField("Senha", text: $password)
                    .textContentType(.password)
                    .submitLabel(.go)
                    .modifier(InputFieldStyle())

                HStack {
                    Spacer()
                    Button("Esqueci minha senha") {
                        router.pushAuth(.passwordReset)
                    }
                    .font(.footnote.weight(.semibold))
                }

                Spacer()
                
                Button(action: submit) {
                    if authViewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Entrar")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isSubmitDisabled)

                Spacer()
                
                Button("Criar nova conta") {
                    router.pushAuth(.signup)
                }
                .font(.footnote.weight(.semibold))
            }
            .frame(maxWidth: 420)
            
            Spacer()

            VStack(spacing: 16) {
                Text("Ou continue com")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    socialButton(label: "G")
                    socialButton(label: "f")
                    socialButton(systemImage: "applelogo")
                }
                .opacity(0.6)
                .disabled(true)
            }
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
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Login")
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("Bem-vindo de volta! Sentimos sua falta.")
                .font(.title2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 24)
        }
        .frame(maxWidth: 420)
    }

    private func socialButton(label: String? = nil, systemImage: String? = nil) -> some View {
        Button {} label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                } else if let label {
                    Text(label)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
            .frame(width: 56, height: 44)
        }
        .buttonStyle(.plain)
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
