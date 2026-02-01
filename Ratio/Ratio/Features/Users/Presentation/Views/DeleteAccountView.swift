//
//  DeleteAccountView.swift
//  Ratio
//
//  Created by Codex on 27/01/26.
//

import AuthenticationServices
import SwiftUI

struct DeleteAccountView: View {
    @StateObject private var viewModel = DeleteAccountViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var appleNonce = ""
    @State private var showErrorAlert = false
    @State private var showPassword = false
    private let analytics = AnalyticsService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Sua conta e todos os dados serão removidos permanentemente. Essa ação não pode ser desfeita.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 420)

                if viewModel.supportsPassword {
                    VStack(spacing: 16) {
                        HStack(spacing: 8) {
                            Group {
                                if showPassword {
                                    TextField("Senha atual", text: $viewModel.password)
                                } else {
                                    SecureField("Senha atual", text: $viewModel.password)
                                }
                            }
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .disabled(viewModel.isLoading)
                        .modifier(InputFieldStyle())

                        Toggle(isOn: $viewModel.hasConfirmed) {
                            Text("Entendo e desejo excluir minha conta")
                                .font(.subheadline)
                        }
                        .toggleStyle(.switch)
                        .padding([.top, .bottom], 16)

                        Button(role: .destructive) {
                            viewModel.deleteWithPassword()
                        } label: {
                            if viewModel.isLoading {
                                ProgressView()
                            } else {
                                Text("Excluir conta")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!viewModel.hasConfirmed || viewModel.password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
                    }
                    .frame(maxWidth: 420)
                }

                if !viewModel.supportsPassword {
                    Toggle(isOn: $viewModel.hasConfirmed) {
                        Text("Entendo e desejo excluir minha conta")
                            .font(.subheadline)
                    }
                    .toggleStyle(.switch)
                    .frame(maxWidth: 420)
                }

                if viewModel.supportsApple || viewModel.supportsGoogle {
                    VStack(spacing: 12) {
                        if viewModel.supportsApple {
                            SignInWithAppleButton(.continue) { request in
                                let nonce = SignInNonce.random()
                                appleNonce = nonce
                                request.requestedScopes = [.email]
                                request.nonce = SignInNonce.sha256(nonce)
                            } onCompletion: { result in
                                switch result {
                                case .success(let auth):
                                    viewModel.deleteWithApple(authorization: auth, rawNonce: appleNonce)
                                case .failure(let error):
                                    viewModel.errorMessage = error.localizedDescription
                                }
                            }
                            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                            .frame(height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .disabled(!viewModel.hasConfirmed || viewModel.isLoading)
                        }

                        if viewModel.supportsGoogle {
                            Button {
                                guard let controller = UIApplication.topViewController() else {
                                    viewModel.errorMessage = "Não foi possível iniciar a confirmação."
                                    return
                                }
                                viewModel.deleteWithGoogle(presenting: controller)
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color(.secondarySystemBackground))
                                    HStack(spacing: 8) {
                                        Image("google-logo")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 18, height: 18)
                                        Text("Continuar com Google")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 48)
                            }
                            .buttonStyle(.plain)
                            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .disabled(!viewModel.hasConfirmed || viewModel.isLoading)
                            .frame(maxWidth: 420)
                        }
                    }
                    .frame(maxWidth: 420)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 32)
        }
        .navigationTitle("Excluir conta")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showErrorAlert = newValue != nil
        }
        .onAppear {
            analytics.screenView(.screen_delete_account)
            viewModel.refreshProviders()
        }
        .alert("Não foi possível excluir a conta", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .overlay {
            if viewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView("Excluindo conta...")
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
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
}

#Preview {
    NavigationStack {
        DeleteAccountView()
    }
}
