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
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel: InviteAcceptanceViewModel
    private let showsCloseButton: Bool
    private let token: String
    private let analytics = AnalyticsService.shared

    init(token: String, showsCloseButton: Bool = false) {
        _viewModel = StateObject(wrappedValue: InviteAcceptanceViewModel(token: token))
        self.showsCloseButton = showsCloseButton
        self.token = token
    }

    var body: some View {
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
                    Text(usageLabel(for: invite))
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
            if showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            analytics.screenView(.screen_invite_accept)
            analytics.track(.invite_open, parameters: ["token": token])
            Task { await viewModel.load() }
        }
        .onChange(of: viewModel.didAccept) { _, newValue in
            if newValue {
                if let groupId = viewModel.inviteInfo?.groupId {
                    router.route(to: .groups, groupId: groupId)
                } else {
                    router.route(to: .groups)
                }
                router.settingsPath = NavigationPath()
                dismiss()
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: date)
    }

    private func usageLabel(for invite: InviteInfo) -> String {
        if invite.maxUses == 0 {
            return "Uso ilimitado"
        }
        if invite.maxUses == 1 {
            return "Uso único"
        }
        return "Usos: \(invite.usesCount)/\(invite.maxUses)"
    }
}

#Preview {
    NavigationStack {
        InviteAcceptanceView(token: "preview", showsCloseButton: true)
            .environmentObject(AuthViewModel())
            .environmentObject(AppRouter())
    }
}
