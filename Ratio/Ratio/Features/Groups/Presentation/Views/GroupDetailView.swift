//
//  GroupDetailView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI

struct GroupDetailView: View {
    let group: Group
    let currentUserId: String?

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
                                .foregroundStyle(member.status == .paid ? .green : .orange)
                        }
                        Spacer()
                        Text(formattedCurrency(member.amount))
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
        }
        .navigationTitle("Detalhes do grupo")
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
                    GroupMember(id: "1", name: "Leo", amount: 20, status: .paid, userId: "1"),
                    GroupMember(id: "2", name: "Pessoa", amount: 20, status: .pending, userId: nil)
                ]
            ),
            currentUserId: "1"
        )
    }
}
