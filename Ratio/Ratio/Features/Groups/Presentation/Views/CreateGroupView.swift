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

    @FocusState private var focusedField: Field?
    @State private var groupName = ""
    @State private var totalAmountText = ""
    @State private var totalAmountValue: Double = 0
    @State private var currencyCode = "BRL"
    @State private var category: GroupCategory = .streaming
    @State private var billingPeriod: BillingPeriod = .monthly
    @State private var billingDay = 5
    @State private var notes = ""
    @State private var splitEqually = true
    @State private var members: [GroupMemberDraft] = []
    @State private var memberValues: [String: Double] = [:]

    enum Field: Hashable {
        case total
        case memberAmount(String)
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
                        let normalizedMembers = normalizedMemberList()
                        let total = totalAmountValue
                        await viewModel.createGroup(
                            name: groupName,
                            category: category,
                            totalAmount: total,
                            currencyCode: currencyCode,
                            billingPeriod: billingPeriod,
                            billingDay: billingDay,
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
                            members: normalizedMembers,
                            ownerId: ownerId
                        )
                        dismiss()
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
            if totalAmountValue > 0 {
                totalAmountText = formatAmount(totalAmountValue)
            }
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

            HStack {
                Text(currencySymbol)
                    .foregroundStyle(.secondary)
                TextField("0,00", text: $totalAmountText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .total)
                    .onChange(of: totalAmountText) { _, newValue in
                        if let value = parseAmount(newValue) {
                            totalAmountValue = value
                        } else if newValue.isEmpty {
                            totalAmountValue = 0
                        }
                    }
                    .onChange(of: focusedField) { oldValue, newValue in
                        if oldValue == .total && newValue != .total {
                            totalAmountText = formatAmount(totalAmountValue)
                        }
                    }
            }

            Picker("Moeda", selection: $currencyCode) {
                Text("BRL").tag("BRL")
                Text("USD").tag("USD")
            }

            Picker("Tipo", selection: $category) {
                ForEach(GroupCategory.allCases) { category in
                    Text(category.label).tag(category)
                }
            }

            Picker("Periodicidade", selection: $billingPeriod) {
                ForEach(BillingPeriod.allCases) { period in
                    Text(period.label).tag(period)
                }
            }

            Stepper(value: $billingDay, in: 1...31) {
                Text("Dia de cobrança: \(billingDay)")
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
                    focusedField: $focusedField,
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
        !members.isEmpty
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

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.currencySymbol
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
