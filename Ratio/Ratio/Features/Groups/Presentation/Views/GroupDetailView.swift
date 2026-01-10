//
//  GroupDetailView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI

struct GroupDetailView: View {
    @State private var group: Group
    let currentUserId: String?
    @StateObject private var paymentsViewModel = GroupPaymentsViewModel()
    @State private var showPaymentSheet = false
    @State private var showPaymentError = false

    init(group: Group, currentUserId: String?) {
        _group = State(initialValue: group)
        self.currentUserId = currentUserId
    }

    var body: some View {
        List {
            Section("Grupo") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.name)
                        .font(.title2.bold())
                    if let subscriptionName = group.subscriptionName {
                        Text(subscriptionName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Total")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formattedCurrency(group.totalAmount))
                        .font(.headline)
                }

                HStack {
                    Text("Periodicidade")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(group.billingPeriod)
                        .foregroundStyle(.secondary)
                }

                if let billingDay = group.chargeDay ?? group.billingDay {
                    HStack {
                        Text("Dia de cobrança do grupo")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(billingDay)")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Categoria")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(group.category.label)
                        .foregroundStyle(.secondary)
                }
            }

            if let currentMember = currentMember {
                Section("Seu pagamento") {
                    HStack {
                        Text("Status")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(currentMember.status.label)
                            .foregroundStyle(statusColor(for: currentMember.status))
                    }

                    if let receiptURL = currentMember.receiptURL,
                       let url = URL(string: receiptURL) {
                        Link("Ver comprovante", destination: url)
                    }

                    if currentMember.status == .pending {
                        Button("Marcar como pago") {
                            showPaymentSheet = true
                        }
                    } else if currentMember.status == .submitted {
                        Text("Aguardando confirmação do organizador.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let notes = group.notes, !notes.isEmpty {
                Section("Observações") {
                    Text(notes)
                }
            }

            Section("Membros") {
                ForEach(orderedMembers) { member in
                    HStack(spacing: 12) {
                        MemberAvatarView(name: member.name)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(memberLabel(for: member))
                                .font(.subheadline.weight(.semibold))
                            Text(member.status.label)
                                .font(.footnote)
                                .foregroundStyle(statusColor(for: member.status))
                        }
                        Spacer()
                        Text(formattedCurrency(member.amount))
                            .font(.subheadline.weight(.semibold))

                        if let receiptURL = member.receiptURL,
                           let url = URL(string: receiptURL) {
                            Link(destination: url) {
                                Image(systemName: "doc.text.magnifyingglass")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }

                        if canApprove(member: member) {
                            Button("Aprovar") {
                                Task {
                                    await paymentsViewModel.approvePayment(groupId: group.id, memberId: member.id)
                                    if paymentsViewModel.errorMessage == nil {
                                        updateMemberStatus(member.id, status: .paid)
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(.green)
                        }
                    }
                }
            }
        }
        .navigationTitle("Detalhes do grupo")
        .sheet(isPresented: $showPaymentSheet) {
            if let currentMember = currentMember {
                NavigationStack {
                    PaymentSubmissionView(
                        groupId: group.id,
                        memberId: currentMember.id,
                        amount: currentMember.amount,
                        currencyCode: group.currencyCode,
                        onSubmitted: {
                            updateMemberStatus(currentMember.id, status: .submitted)
                        }
                    )
                }
            }
        }
        .alert("Erro", isPresented: $showPaymentError) {
            Button("Ok", role: .cancel) {}
        } message: {
            Text(paymentsViewModel.errorMessage ?? "Não foi possível atualizar o pagamento.")
        }
        .onChange(of: paymentsViewModel.errorMessage) { _, newValue in
            showPaymentError = newValue != nil
        }
    }

    private func memberLabel(for member: GroupMember) -> String {
        let isOwner = member.userId == group.ownerId
        let isCurrentUser = currentUserId == member.userId

        switch (isOwner, isCurrentUser) {
        case (true, true):
            return "\(member.name) (Você • Organizador)"
        case (true, false):
            return "\(member.name) (Organizador)"
        case (false, true):
            return "\(member.name) (Você)"
        default:
            return member.name
        }
    }

    private func formattedCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = group.currencyCode
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }

    private func statusColor(for status: GroupMemberStatus) -> Color {
        switch status {
        case .paid:
            return .green
        case .pending:
            return .orange
        case .submitted:
            return .blue
        }
    }

    private var orderedMembers: [GroupMember] {
        guard let ownerId = group.ownerId else { return group.members }
        return group.members.sorted { lhs, rhs in
            let lhsIsOwner = lhs.userId == ownerId
            let rhsIsOwner = rhs.userId == ownerId
            if lhsIsOwner != rhsIsOwner {
                return lhsIsOwner
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var currentMember: GroupMember? {
        guard let currentUserId else { return nil }
        return group.members.first { $0.userId == currentUserId }
    }

    private func canApprove(member: GroupMember) -> Bool {
        guard let ownerId = group.ownerId, ownerId == currentUserId else { return false }
        return member.status == .submitted
    }

    private func updateMemberStatus(_ memberId: String, status: GroupMemberStatus) {
        group = Group(
            id: group.id,
            name: group.name,
            category: group.category,
            totalAmount: group.totalAmount,
            currencyCode: group.currencyCode,
            billingPeriod: group.billingPeriod,
            billingDay: group.billingDay,
            notes: group.notes,
            ownerId: group.ownerId,
            subscriptionId: group.subscriptionId,
            subscriptionName: group.subscriptionName,
            subscriptionCategory: group.subscriptionCategory,
            subscriptionPeriod: group.subscriptionPeriod,
            subscriptionNextBillingDate: group.subscriptionNextBillingDate,
            chargeDay: group.chargeDay,
            chargeNextBillingDate: group.chargeNextBillingDate,
            members: group.members.map { member in
                guard member.id == memberId else { return member }
                return GroupMember(
                    id: member.id,
                    name: member.name,
                    amount: member.amount,
                    status: status,
                    userId: member.userId,
                    receiptURL: member.receiptURL,
                    submittedAt: status == .submitted ? Date() : member.submittedAt,
                    approvedAt: status == .paid ? Date() : member.approvedAt
                )
            }
        )
    }
}

#Preview {
    NavigationStack {
        GroupDetailView(
            group: Group(
                id: "preview",
                name: "Netflix",
                category: .streaming,
                totalAmount: 59.9,
                currencyCode: "BRL",
                billingPeriod: "Mensal",
                billingDay: 5,
                notes: "Teste",
                ownerId: "1",
                subscriptionId: "sub",
                subscriptionName: "Netflix",
                subscriptionCategory: "streaming",
                subscriptionPeriod: "monthly",
                subscriptionNextBillingDate: Date(),
                chargeDay: 9,
                chargeNextBillingDate: Date(),
                members: [
                    GroupMember(id: "1", name: "Leo", amount: 20, status: .paid, userId: "1", receiptURL: nil, submittedAt: nil, approvedAt: nil),
                    GroupMember(id: "2", name: "Pessoa", amount: 20, status: .pending, userId: nil, receiptURL: nil, submittedAt: nil, approvedAt: nil)
                ]
            ),
            currentUserId: "1"
        )
    }
}
