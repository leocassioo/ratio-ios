//
//  InviteAcceptanceView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import FirebaseAuth
import SwiftUI

struct InviteAcceptanceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel: InviteAcceptanceViewModel

    init(token: String) {
        _viewModel = StateObject(wrappedValue: InviteAcceptanceViewModel(token: token))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView("Carregando convite...")
                } else if let message = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text(message)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                } else if let invite = viewModel.inviteInfo {
                    VStack(spacing: 10) {
                        Text("Convite para")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(invite.groupName)
                            .font(.title2.bold())
                    }

                    VStack(spacing: 6) {
                        Text("Expira em \(formattedDate(invite.expiresAt))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("Uso único")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button("Entrar no grupo") {
                        guard let user = authViewModel.user else { return }
                        Task {
                            await viewModel.accept(userId: user.uid, fallbackName: user.displayName)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(authViewModel.user == nil || viewModel.isLoading)

                    if authViewModel.user == nil {
                        Text("Entre com sua conta para aceitar o convite.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Convite")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                Task { await viewModel.load() }
            }
            .onChange(of: viewModel.didAccept) { _, newValue in
                if newValue {
                    dismiss()
                }
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: date)
    }
}

#Preview {
    InviteAcceptanceView(token: "preview")
        .environmentObject(AuthViewModel())
}
