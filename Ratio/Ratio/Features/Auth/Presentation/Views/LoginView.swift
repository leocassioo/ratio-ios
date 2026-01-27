//
//  LoginView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(PreferencesStore.PrefKey.pendingEmailChangeNotice) private var showEmailChangeNotice = false
    @State private var showErrorAlert = false
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var appleNonce = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
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

                    HStack(spacing: 8) {
                        if isPasswordVisible {
                            TextField("Senha", text: $password)
                                .textContentType(.password)
                                .submitLabel(.go)
                        } else {
                            SecureField("Senha", text: $password)
                                .textContentType(.password)
                                .submitLabel(.go)
                        }
                        Button {
                            isPasswordVisible.toggle()
                        } label: {
                            Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                    }
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
                
            VStack(spacing: 16) {
                
                Spacer()
                
                Text("Ou continue com")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    googleButton
                    appleButton
                }
                Spacer()
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
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 32)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Login")
        .onChange(of: authViewModel.errorMessage) { _, newValue in
            showErrorAlert = newValue != nil
        }
        .alert("Não foi possível entrar", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authViewModel.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("Bem-vindo de volta! Sentimos sua falta.")
                .font(.title2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 24)
        }
        .frame(maxWidth: 400)
    }

    private var googleButton: some View {
        Button {
            guard let controller = UIApplication.topViewController() else {
                authViewModel.errorMessage = "Não foi possível iniciar o login."
                return
            }
            authViewModel.signInWithGoogle(presenting: controller)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                Image("google-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .disabled(authViewModel.isLoading)
    }

    private var appleButton: some View {
        ZStack {
            SignInWithAppleButton(.signIn) { request in
                let nonce = SignInNonce.random()
                appleNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = SignInNonce.sha256(nonce)
            } onCompletion: { result in
                switch result {
                case .success(let auth):
                    authViewModel.signInWithApple(authorization: auth, rawNonce: appleNonce)
                case .failure(let error):
                    authViewModel.errorMessage = error.localizedDescription
                }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .disabled(authViewModel.isLoading)
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
        authViewModel.isLoading || !email.isValidEmail || password.isEmpty
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(AuthViewModel())
            .environmentObject(AppRouter())
    }
}
