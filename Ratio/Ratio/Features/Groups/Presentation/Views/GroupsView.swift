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
    @StateObject private var viewModel = GroupsViewModel()
    @State private var showCreateGroup = false
    @State private var selectedGroup: Group?

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
                                GroupCardView(group: group, currentUserId: authViewModel.user?.uid) {
                                    selectedGroup = group
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
                        showCreateGroup = true
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
        }
    }
}

#Preview {
    GroupsView()
        .environmentObject(AuthViewModel())
}
