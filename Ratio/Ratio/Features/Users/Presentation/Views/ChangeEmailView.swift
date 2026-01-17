//
//  ChangeEmailView.swift
//  Ratio
//
//  Created by Codex on 20/02/26.
//

import SwiftUI

struct ChangeEmailView: View {
    @StateObject private var viewModel = ChangeEmailViewModel()

    var body: some View {
        let isLocked = viewModel.isLoading || viewModel.successMessage != nil
        Form {
            Section {
                TextField("Novo email", text: $viewModel.newEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(isLocked)

                SecureField("Senha atual", text: $viewModel.currentPassword)
                    .disabled(isLocked)
            } header: {
                Text("Alterar email")
            } footer: {
                Text("Por segurança, confirme sua senha atual.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
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
                .disabled(isLocked)
            }

            if let message = viewModel.errorMessage {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            if let successMessage = viewModel.successMessage {
                Section {
                    Text(successMessage)
                        .font(.footnote)
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("Alterar email")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ChangeEmailView()
    }
}
