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
    @EnvironmentObject private var navigationState: AppNavigationState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var viewModel = GroupsViewModel()
    @State private var showCreateGroup = false
    @State private var selectedGroup: SharedGroup?
    @State private var selectedGroupDetail: SharedGroup?
    @State private var showUpgradePrompt = false
    @State private var showPaywall = false
    private let freeGroupLimit = 2

    var body: some View {
        NavigationStack {
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
                                        selectedGroup = group
                                    }
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .onTapGesture {
                                    selectedGroupDetail = group
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
                            showCreateGroup = true
                        } else {
                            showUpgradePrompt = true
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
                refreshSelectedGroupDetailIfNeeded()
            }
            .onChange(of: navigationState.pendingGroupId) { _, _ in
                openPendingGroupIfNeeded()
            }
            .onDisappear {
                viewModel.stopListening()
            }
            .sheet(isPresented: $showCreateGroup) {
                if let userId = authViewModel.user?.uid {
                    NavigationStack {
                        CreateGroupView(
                            viewModel: viewModel,
                            ownerId: userId,
                            ownerName: authViewModel.user?.displayName ?? ""
                        )
                    }
                }
            }
            .sheet(item: $selectedGroup) { group in
                if let userId = authViewModel.user?.uid {
                    NavigationStack {
                        EditGroupView(
                            viewModel: viewModel,
                            group: group,
                            ownerId: userId
                        )
                    }
                }
            }
            .sheet(item: $selectedGroupDetail) { group in
                NavigationStack {
                    GroupDetailView(
                        group: group,
                        currentUserId: authViewModel.user?.uid
                    )
                }
            }
            .sheet(isPresented: $showUpgradePrompt) {
                UpgradePromptView(
                    title: "Limite de grupos no plano gratuito",
                    subtitle: "Você chegou ao limite de \(freeGroupLimit) grupos. Assine o Ratio Pro para criar grupos ilimitados.",
                    benefits: [
                        "Grupos compartilhados ilimitados",
                        "Mais controle sobre cobranças e rateios",
                        "Prioridade para novos recursos"
                    ],
                    onViewPlans: {
                        showPaywall = true
                    }
                )
            }
            .fullScreenCover(isPresented: $showPaywall) {
                NavigationStack {
                    SubscriptionBenefitsView()
                        .environmentObject(subscriptionManager)
                }
            }
        }
    }

    private var canCreateGroup: Bool {
        subscriptionManager.isProUser || viewModel.groups.count < freeGroupLimit
    }

    private func openPendingGroupIfNeeded() {
        guard let groupId = navigationState.pendingGroupId else { return }
        guard let group = viewModel.groups.first(where: { $0.id == groupId }) else { return }
        selectedGroupDetail = group
        navigationState.pendingGroupId = nil
    }

    private func refreshSelectedGroupDetailIfNeeded() {
        guard let selectedGroupDetail else { return }
        guard let updated = viewModel.groups.first(where: { $0.id == selectedGroupDetail.id }) else { return }
        self.selectedGroupDetail = updated
    }
}

#Preview {
    GroupsView()
        .environmentObject(AuthViewModel())
        .environmentObject(SubscriptionManager.shared)
}
