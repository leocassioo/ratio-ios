//
//  GroupCardView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI

struct GroupCardView: View {
    let group: SharedGroup
    let currentUserId: String?
    let currentUserPixKey: String?
    let preferredCurrencyCode: String
    let estimatedTotal: Double?
    let estimatedMember: (Double) -> Double?
    let onEdit: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.headline)
                    Text("Total: \(formattedCurrency(group.totalAmount)) / \(group.billingPeriod)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let estimatedTotal, group.currencyCode != preferredCurrencyCode {
                        Text("Estimado em \(preferredCurrencyCode): \(formattedCurrency(estimatedTotal, currencyCode: preferredCurrencyCode))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let nextChargeDate = nextChargeDate {
                        Text("Próxima cobrança: \(formattedDate(nextChargeDate))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Text(group.category.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    GroupAvatarStack(members: group.members)
                    if canEdit {
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
            }

            Divider()

            VStack(spacing: 12) {
                ForEach(orderedMembers) { member in
                    HStack(spacing: 12) {
                        MemberAvatarView(name: member.name, photoURL: member.photoURL)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(memberDisplayName(for: member))
                                    .font(.subheadline.weight(.semibold))
                                if let roleLabel = memberRoleLabel(for: member) {
                                    Text(roleLabel)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(member.status.label)
                                .font(.footnote)
                                .foregroundStyle(statusColor(for: member.status))
                        }

                        Spacer()

                        if canEdit, member.status != .paid, member.userId != currentUserId {
                            Button {
                                Task {
                                    let usersStore = UsersStore()
                                    var phoneNumber: String?
                                    if let userId = member.userId {
                                        if let profile = try? await usersStore.fetchUserProfile(userId: userId) {
                                            phoneNumber = profile.phoneNumber
                                        }
                                    }
                                    
                                    if let url = WhatsAppMessageBuilder.buildPaymentRequest(
                                        memberName: member.name,
                                        groupName: group.name,
                                        amount: member.amount,
                                        currencyCode: group.currencyCode,
                                        pixKey: (group.pixKey?.isEmpty == false) ? group.pixKey : currentUserPixKey,
                                        phoneNumber: phoneNumber
                                    ) {
                                        await MainActor.run {
                                            UIApplication.shared.open(url)
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "bell.fill")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .padding(6)
                                    .background(Circle().fill(Color.orange))
                            }
                            .buttonStyle(.plain)
                        }

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formattedCurrency(member.amount))
                                .font(.subheadline.weight(.semibold))
                            if let estimated = estimatedMember(member.amount), group.currencyCode != preferredCurrencyCode {
                                Text("≈ \(formattedCurrency(estimated, currencyCode: preferredCurrencyCode))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(borderOpacity), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 8)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground)
    }

    private var borderOpacity: Double {
        colorScheme == .dark ? 0.4 : 0.25
    }

    private func memberDisplayName(for member: GroupMember) -> String {
        let displayName = firstName(from: member.name)
        return displayName
    }

    private func memberRoleLabel(for member: GroupMember) -> String? {
        let isOwner = member.userId == group.ownerId
        let isCurrentUser = currentUserId == member.userId

        switch (isOwner, isCurrentUser) {
        case (true, true):
            return "Você • Organizador"
        case (true, false):
            return "Organizador"
        case (false, true):
            return "Você"
        default:
            return nil
        }
    }

    private func firstName(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.split(separator: " ").first.map(String.init) ?? trimmed
    }

    private func formattedCurrency(_ value: Double, currencyCode: String? = nil) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode ?? group.currencyCode
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
        case .overdue:
            return .red
        }
    }

    private var nextChargeDate: Date? {
        group.chargeNextBillingDate ?? group.subscriptionNextBillingDate
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .short
        return formatter.string(from: date)
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

    private var canEdit: Bool {
        guard let currentUserId, let ownerId = group.ownerId else { return false }
        return currentUserId == ownerId
    }
}
