//
//  GroupCardView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI

struct GroupCardView: View {
    let group: Group
    let currentUserId: String?
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.headline)
                    Text("Total: \(formattedCurrency(group.totalAmount)) / \(group.billingPeriod)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(group.category.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    GroupAvatarStack(members: group.members)
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(6)
                            .background(Circle().fill(Color(.tertiarySystemBackground)))
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            VStack(spacing: 12) {
                ForEach(group.members) { member in
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 8)
    }

    private func memberLabel(for member: GroupMember) -> String {
        if let currentUserId, currentUserId == member.userId {
            return "\(member.name) (Você)"
        }
        return member.name
    }

    private func formattedCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = group.currencyCode
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }
}
