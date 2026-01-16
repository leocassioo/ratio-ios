//
//  GroupsView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import FirebaseAuth
import SwiftUI

struct GroupsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var viewModel = GroupsViewModel()
    private let freeGroupLimit = 2

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
            } else if let message = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if viewModel.groups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.3")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Nenhum grupo ainda")
                        .font(.headline)
                    Text("Crie seu primeiro grupo para compartilhar assinaturas.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 260)
                }
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(viewModel.groups) { group in
                            GroupCardView(
                                group: group,
                                currentUserId: authViewModel.user?.uid,
                                currentUserPixKey: authViewModel.userPixKey,
                                onEdit: {
                                    openEdit(group)
                                }
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .onTapGesture {
                                openDetail(group)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Grupos")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if canCreateGroup {
                        openCreate()
                    } else {
                        router.present(.upgradePrompt(
                            title: "Limite de grupos no plano gratuito",
                            subtitle: "Você chegou ao limite de \(freeGroupLimit) grupos. Assine o Ratio Pro para criar grupos ilimitados.",
                            benefits: [
                                "Grupos compartilhados ilimitados",
                                "Mais controle sobre cobranças e rateios",
                                "Prioridade para novos recursos"
                            ]
                        ))
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            if let userId = authViewModel.user?.uid {
                viewModel.startListening(userId: userId)
            }
        }
        .onChange(of: viewModel.groups) { _, _ in
            openPendingGroupIfNeeded()
            refreshGroupDetailIfNeeded()
        }
        .onChange(of: router.pendingGroupId) { _, _ in
            openPendingGroupIfNeeded()
        }
        .onDisappear {
            viewModel.stopListening()
        }
    }

    private var canCreateGroup: Bool {
        subscriptionManager.isProUser || viewModel.groups.count < freeGroupLimit
    }

    private func openPendingGroupIfNeeded() {
        guard let groupId = router.pendingGroupId else { return }
        guard let group = viewModel.groups.first(where: { $0.id == groupId }) else { return }
        router.present(.groupDetail(group: group, currentUserId: authViewModel.user?.uid))
        router.pendingGroupId = nil
    }

    private func refreshGroupDetailIfNeeded() {
        guard case .groupDetail(let currentGroup, let currentUserId) = router.sheet else { return }
        guard let updated = viewModel.groups.first(where: { $0.id == currentGroup.id }) else { return }
        router.present(.groupDetail(group: updated, currentUserId: currentUserId))
    }

    private func openCreate() {
        guard let userId = authViewModel.user?.uid else { return }
        router.present(.createGroup(
            ownerId: userId,
            ownerName: authViewModel.user?.displayName ?? "",
            viewModel: viewModel
        ))
    }

    private func openEdit(_ group: SharedGroup) {
        guard let userId = authViewModel.user?.uid else { return }
        router.present(.editGroup(group: group, ownerId: userId, viewModel: viewModel))
    }

    private func openDetail(_ group: SharedGroup) {
        router.present(.groupDetail(group: group, currentUserId: authViewModel.user?.uid))
    }
}

#Preview {
    GroupsView()
        .environmentObject(AuthViewModel())
        .environmentObject(SubscriptionManager.shared)
        .environmentObject(AppRouter())
}
