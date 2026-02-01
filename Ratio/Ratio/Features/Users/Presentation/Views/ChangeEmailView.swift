//
//  ChangeEmailView.swift
//  Ratio
//
//  Created by Codex on 20/02/26.
//

import SwiftUI

struct ChangeEmailView: View {
    @StateObject private var viewModel = ChangeEmailViewModel()
    @State private var showErrorAlert = false
    private let analytics = AnalyticsService.shared

    var body: some View {
        let isLocked = viewModel.isLoading || viewModel.successMessage != nil
        let isSubmitDisabled = isLocked ||
        !viewModel.newEmail.isValidEmail ||
        viewModel.currentPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Insira os dados \npara seguir.")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 20) {
                    TextField("Novo email", text: $viewModel.newEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(isLocked)
                        .modifier(InputFieldStyle())

                    SecureField("Senha atual", text: $viewModel.currentPassword)
                        .disabled(isLocked)
                        .modifier(InputFieldStyle())

                    Text("Por segurança, confirme sua senha atual.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 420)

                Button {
                    viewModel.updateEmail()
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Atualizar email")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isSubmitDisabled)
                .frame(maxWidth: 420)

                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }

                if let successMessage = viewModel.successMessage {
                    Text(successMessage)
                        .font(.footnote)
                        .foregroundStyle(.green)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 32)
        }
        .navigationTitle("Alterar email")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            analytics.screenView(.screen_change_email)
            analytics.track(.settings_change_email_open)
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showErrorAlert = newValue != nil
        }
        .alert("Não foi possível alterar o email", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
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
        ChangeEmailView()
    }
}
