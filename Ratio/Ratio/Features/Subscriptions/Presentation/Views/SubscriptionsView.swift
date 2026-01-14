//
//  SubscriptionsView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI
import FirebaseAuth

struct SubscriptionsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = SubscriptionsViewModel()
    @State private var showCreate = false
    @State private var showErrorAlert = false
    @State private var selectedSubscription: SubscriptionItem?
    @State private var pendingDelete: SubscriptionItem?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView()
                } else if let message = viewModel.errorMessage, viewModel.subscriptions.isEmpty {
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
                } else if viewModel.subscriptions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "creditcard")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Sem assinaturas ainda")
                            .font(.headline)
                        Text("Cadastre sua primeira assinatura.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 260)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(viewModel.subscriptions) { subscription in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(subscription.name)
                                        .font(.headline)
                                    Spacer()
                                    Text(formattedCurrency(subscription.amount, currencyCode: subscription.currencyCode))
                                        .font(.subheadline.weight(.semibold))
                                }
                                Text(subscription.period.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(subscription.category.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Próxima cobrança: \(formattedDate(subscription.nextBillingDate))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedSubscription = subscription
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Editar") {
                                    selectedSubscription = subscription
                                }
                                .tint(.blue)
                                if canDelete(subscription) {
                                    Button(role: .destructive) {
                                        pendingDelete = subscription
                                        showDeleteConfirm = true
                                    } label: {
                                        Text("Excluir")
                                    }
                                }
                            }
                        }
                        .onDelete(perform: deleteSubscription)
                    }
                }
            }
            .navigationTitle("Assinaturas")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreate) {
                if let userId = authViewModel.user?.uid {
                    NavigationStack {
                        CreateSubscriptionView { newSubscription in
                            Task {
                                await viewModel.createSubscription(
                                    name: newSubscription.name,
                                    amount: newSubscription.amount,
                                    currencyCode: newSubscription.currencyCode,
                                    category: newSubscription.category,
                                    period: newSubscription.period,
                                    nextBillingDate: newSubscription.nextBillingDate,
                                    notes: newSubscription.notes.isEmpty ? nil : newSubscription.notes,
                                    ownerId: userId
                                )
                            }
                        }
                    }
                }
            }
            .sheet(item: $selectedSubscription) { subscription in
                if let userId = authViewModel.user?.uid {
                    NavigationStack {
                        EditSubscriptionView(
                            subscription: subscription,
                            canDelete: canDelete(subscription),
                            onDelete: {
                                pendingDelete = subscription
                                showDeleteConfirm = true
                            }
                        ) { updated in
                            Task {
                                await viewModel.updateSubscription(
                                    id: updated.id,
                                    name: updated.name,
                                    amount: updated.amount,
                                    currencyCode: updated.currencyCode,
                                    category: updated.category,
                                    period: updated.period,
                                    nextBillingDate: updated.nextBillingDate,
                                    notes: updated.notes.isEmpty ? nil : updated.notes,
                                    ownerId: userId
                                )
                            }
                        }
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
            .onChange(of: viewModel.errorMessage) { _, newValue in
                showErrorAlert = newValue != nil
            }
            .alert("Não foi possível excluir", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("Excluir assinatura", isPresented: $showDeleteConfirm) {
                Button("Cancelar", role: .cancel) {}
                Button("Excluir", role: .destructive) {
                    if let subscription = pendingDelete {
                        deleteSubscription(subscription)
                    }
                    pendingDelete = nil
                }
            } message: {
                Text("Tem certeza que deseja excluir esta assinatura? Essa ação não pode ser desfeita.")
            }
        }
    }

    private func deleteSubscription(at offsets: IndexSet) {
        guard let userId = authViewModel.user?.uid else { return }
        let ids = offsets.map { viewModel.subscriptions[$0].id }
        Task {
            for id in ids {
                await viewModel.deleteSubscription(id: id, ownerId: userId)
            }
        }
    }

    private func deleteSubscription(_ subscription: SubscriptionItem) {
        guard let userId = authViewModel.user?.uid else { return }
        Task {
            await viewModel.deleteSubscription(id: subscription.id, ownerId: userId)
        }
    }

    private func canDelete(_ subscription: SubscriptionItem) -> Bool {
        guard viewModel.hasLoadedGroups else { return false }
        return !viewModel.linkedSubscriptionIds.contains(subscription.id)
    }

    private func formattedCurrency(_ value: Double, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: date)
    }
}

#Preview {
    SubscriptionsView()
        .environmentObject(AuthViewModel())
}
