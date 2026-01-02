//
//  CreateGroupView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: GroupsViewModel
    let ownerId: String
    let ownerName: String

    @State private var groupName = ""
    @State private var selectedSubscriptionId: String?
    @State private var totalAmountValue: Double = 0
    @State private var currencyCode = "BRL"
    @State private var billingPeriodLabel = ""
    @State private var billingDay = 1
    @State private var notes = ""
    @State private var splitEqually = true
    @State private var members: [GroupMemberDraft] = []
    @State private var memberValues: [String: Double] = [:]
    @StateObject private var creationViewModel: GroupCreationViewModel

    init(viewModel: GroupsViewModel, ownerId: String, ownerName: String) {
        self.viewModel = viewModel
        self.ownerId = ownerId
        self.ownerName = ownerName
        _creationViewModel = StateObject(wrappedValue: GroupCreationViewModel(ownerId: ownerId))
    }

    var body: some View {
        Form {
            groupSection
            notesSection
            membersSection
        }
        .navigationTitle("Novo grupo")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") {
                    Task {
                        if let subscription = selectedSubscription {
                            let normalizedMembers = normalizedMemberList()
                            await viewModel.createGroup(
                                name: groupName,
                                subscription: subscription,
                                billingDay: billingDay,
                                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
                                members: normalizedMembers,
                                ownerId: ownerId
                            )
                            dismiss()
                        }
                    }
                }
                .disabled(!canSubmit)
            }
        }
        .onAppear {
            if members.isEmpty {
                members = [
                    GroupMemberDraft(
                        id: UUID().uuidString,
                        name: ownerName.isEmpty ? "Você" : ownerName,
                        amountText: "",
                        status: .paid,
                        userId: ownerId
                    )
                ]
            }
            updateSelectedSubscription()
            creationViewModel.startListening()
        }
        .onDisappear {
            creationViewModel.stopListening()
        }
        .onChange(of: splitEqually) { _, newValue in
            if newValue {
                applyEqualSplit()
            }
        }
        .onChange(of: totalAmountValue) { _, _ in
            if splitEqually {
                applyEqualSplit()
            }
        }
        .onChange(of: members.count) { _, _ in
            if splitEqually {
                applyEqualSplit()
            }
        }
        .onChange(of: selectedSubscriptionId) { _, _ in
            updateSelectedSubscription()
        }
    }

    private var groupSection: some View {
        Section("Grupo") {
            TextField("Nome do grupo", text: $groupName)

            Picker("Assinatura", selection: $selectedSubscriptionId) {
                Text("Selecione uma assinatura").tag(Optional<String>.none)
                ForEach(creationViewModel.subscriptions) { subscription in
                    Text(subscription.name).tag(Optional(subscription.id))
                }
            }

            if let subscription = selectedSubscription {
                HStack {
                    Text("Total")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formattedCurrency(subscription.amount, currencyCode: subscription.currencyCode))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Periodicidade")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(subscription.period.label)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Tipo")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(subscription.category.label)
                        .foregroundStyle(.secondary)
                }

                Stepper(value: $billingDay, in: 1...31) {
                    Text("Dia de cobrança: \(billingDay)")
                }
            }

            Toggle("Dividir igualmente", isOn: $splitEqually)
        }
    }

    private var notesSection: some View {
        Section("Observações") {
            TextField("Detalhes do grupo", text: $notes, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
        }
    }

    private var membersSection: some View {
        Section("Membros") {
            ForEach($members) { $member in
                MemberRowView(
                    member: $member,
                    currencySymbol: currencySymbol,
                    splitEqually: splitEqually,
                    memberValues: $memberValues,
                    parseAmount: parseAmount,
                    formatAmount: formatAmount
                )
            }
            .onDelete(perform: deleteMember)

            Button("Adicionar membro") {
                members.append(GroupMemberDraft(id: UUID().uuidString, name: "", amountText: "", status: .pending, userId: nil))
            }
        }
    }

    private var canSubmit: Bool {
        !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        totalAmountValue > 0 &&
        !members.isEmpty &&
        selectedSubscription != nil
    }

    private func normalizedMemberList() -> [GroupMemberDraft] {
        members
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { member in
                var copy = member
                if splitEqually, let value = memberValues[member.id] {
                    copy.amountText = formatAmount(value)
                }
                if copy.userId == nil && copy.name == ownerName {
                    copy.userId = ownerId
                }
                return copy
            }
    }

    private func deleteMember(at offsets: IndexSet) {
        members.remove(atOffsets: offsets)
    }

    private func applyEqualSplit() {
        guard !members.isEmpty else { return }
        let value = totalAmountValue / Double(members.count)
        members = members.map { member in
            var copy = member
            copy.amountText = formatAmount(value)
            return copy
        }
        members.forEach { memberValues[$0.id] = value }
    }

    private func updateSelectedSubscription() {
        guard let subscription = selectedSubscription else {
            totalAmountValue = 0
            currencyCode = "BRL"
            billingPeriodLabel = ""
            billingDay = 1
            return
        }

        totalAmountValue = subscription.amount
        currencyCode = subscription.currencyCode
        billingPeriodLabel = subscription.period.label
        billingDay = Calendar.current.component(.day, from: subscription.nextBillingDate)
        updateSplitAmounts()
    }

    private func updateSplitAmounts() {
        if splitEqually {
            applyEqualSplit()
        }
    }

    private func parseAmount(_ text: String) -> Double? {
        let cleanText = text.replacingOccurrences(of: ",", with: ".")
        return Double(cleanText)
    }

    private func formatAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "0,00"
    }

    private func formattedCurrency(_ value: Double, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.currencySymbol
    }

    private var selectedSubscription: SubscriptionItem? {
        guard let selectedSubscriptionId else { return nil }
        return creationViewModel.subscriptions.first { $0.id == selectedSubscriptionId }
    }
}


#Preview {
    NavigationStack {
        CreateGroupView(
            viewModel: GroupsViewModel(),
            ownerId: "preview",
            ownerName: "Leonardo"
        )
    }
}
