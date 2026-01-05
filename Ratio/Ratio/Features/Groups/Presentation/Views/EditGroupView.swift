//
//  EditGroupView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI

struct EditGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: GroupsViewModel
    let group: Group
    let ownerId: String

    @State private var groupName: String
    @State private var selectedSubscriptionId: String?
    @State private var totalAmountValue: Double
    @State private var currencyCode: String
    @State private var billingDay: Int
    @State private var notes: String
    @State private var splitEqually: Bool = true
    @State private var members: [GroupMemberDraft]
    @State private var memberValues: [String: Double] = [:]
    @State private var newMemberName = ""
    @State private var showDeleteAlert = false
    @StateObject private var creationViewModel: GroupCreationViewModel

    init(viewModel: GroupsViewModel, group: Group, ownerId: String) {
        self.viewModel = viewModel
        self.group = group
        self.ownerId = ownerId
        _groupName = State(initialValue: group.name)
        _selectedSubscriptionId = State(initialValue: group.subscriptionId)
        _totalAmountValue = State(initialValue: group.totalAmount)
        _currencyCode = State(initialValue: group.currencyCode)
        _billingDay = State(initialValue: group.billingDay ?? 1)
        _notes = State(initialValue: group.notes ?? "")
        _members = State(initialValue: group.members.map {
            GroupMemberDraft(
                id: $0.id,
                name: $0.name,
                amountText: $0.amount.formatted(.number.precision(.fractionLength(2))),
                status: $0.status,
                userId: $0.userId
            )
        })
        _creationViewModel = StateObject(wrappedValue: GroupCreationViewModel(ownerId: ownerId))
    }

    var body: some View {
        Form {
            groupSection
            notesSection
            membersSection
            if perPersonAmount > 0 {
                summarySection
            }
            deleteSection
        }
        .navigationTitle("Editar grupo")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") {
                    Task {
                        if let subscription = selectedSubscriptionForSave {
                            let normalizedMembers = normalizedMemberList()
                            await viewModel.updateGroup(
                                groupId: group.id,
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
        .alert("Excluir grupo?", isPresented: $showDeleteAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Excluir", role: .destructive) {
                Task {
                    await viewModel.deleteGroup(groupId: group.id)
                    dismiss()
                }
            }
        } message: {
            Text("Essa ação é permanente e remove o grupo para todos os membros.")
        }
        .onAppear {
            creationViewModel.startListening()
            updateSelectedSubscription()
        }
        .onDisappear {
            creationViewModel.stopListening()
        }
        .onChange(of: selectedSubscriptionId) { _, _ in
            updateSelectedSubscription()
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
            HStack {
                TextField("Nome do membro", text: $newMemberName)
                    .submitLabel(.done)
                    .onSubmit(addMember)
                Button {
                    addMember()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(newMemberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

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
        }
    }

    private var summarySection: some View {
        Section {
            HStack {
                Text("Por pessoa")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formattedCurrency(perPersonAmount, currencyCode: currencyCode))
                    .font(.headline)
            }
        } header: {
            Text("Resumo")
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Text("Excluir grupo")
            }
        }
    }

    private var canSubmit: Bool {
        !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        totalAmountValue > 0 &&
        !members.isEmpty &&
        selectedSubscriptionForSave != nil
    }

    private func normalizedMemberList() -> [GroupMemberDraft] {
        members
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { member in
                var copy = member
                if splitEqually, let value = memberValues[member.id] {
                    copy.amountText = formatAmount(value)
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
            billingDay = 1
            return
        }

        totalAmountValue = subscription.amount
        currencyCode = subscription.currencyCode
        if groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            groupName = subscription.name
        }
        if billingDay <= 0 {
            billingDay = Calendar.current.component(.day, from: subscription.nextBillingDate)
        }
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

    private func addMember() {
        let trimmed = newMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        members.append(GroupMemberDraft(id: UUID().uuidString, name: trimmed, amountText: "", status: .pending, userId: nil))
        newMemberName = ""
        if splitEqually {
            applyEqualSplit()
        }
    }

    private var perPersonAmount: Double {
        guard !members.isEmpty else { return 0 }
        return totalAmountValue / Double(members.count)
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

    private var selectedSubscriptionForSave: SubscriptionItem? {
        if let selectedSubscription {
            return selectedSubscription
        }

        guard let subscriptionId = group.subscriptionId else { return nil }
        let period = SubscriptionPeriod(rawValue: group.subscriptionPeriod ?? "") ?? .monthly
        let category = SubscriptionCategory(rawValue: group.subscriptionCategory ?? "") ?? .other
        return SubscriptionItem(
            id: subscriptionId,
            name: group.subscriptionName ?? group.name,
            amount: group.totalAmount,
            currencyCode: group.currencyCode,
            category: category,
            period: period,
            nextBillingDate: group.subscriptionNextBillingDate ?? Date(),
            notes: group.notes ?? ""
        )
    }
}

#Preview {
    NavigationStack {
        EditGroupView(
            viewModel: GroupsViewModel(),
            group: Group(
                id: "preview",
                name: "Netflix",
                category: .streaming,
                totalAmount: 59.9,
                currencyCode: "BRL",
                billingPeriod: "Mensal",
                billingDay: 5,
                notes: "Teste",
                subscriptionId: "sub",
                subscriptionName: "Netflix",
                subscriptionCategory: "streaming",
                subscriptionPeriod: "monthly",
                subscriptionNextBillingDate: Date(),
                members: [
                    GroupMember(id: "1", name: "Leo", amount: 20, status: .paid, userId: "1"),
                    GroupMember(id: "2", name: "Pessoa", amount: 20, status: .pending, userId: nil)
                ]
            ),
            ownerId: "preview"
        )
    }
}
