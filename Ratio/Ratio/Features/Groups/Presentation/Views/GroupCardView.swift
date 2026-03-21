//
//  GroupCardView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI

struct GroupCardView: View {
    private struct SharePayload: Identifiable {
        let id = UUID()
        let items: [Any]
    }

    let group: SharedGroup
    let currentUserId: String?
    let currentUserPixKey: String?
    let preferredCurrencyCode: String
    let estimatedTotal: Double?
    let estimatedMember: (Double) -> Double?
    let onEdit: () -> Void
    let onMarkPaid: (_ groupId: String, _ memberId: String) -> Void
    let isMarkingPaid: (_ groupId: String, _ memberId: String) -> Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var sharePayload: SharePayload?

    var body: some View {
        cardContent(showTopActions: true, showMemberActions: true, includeShadow: true)
            .sheet(item: $sharePayload) { payload in
                ShareSheet(items: payload.items)
            }
    }

    @ViewBuilder
    private func cardContent(showTopActions: Bool, showMemberActions: Bool, includeShadow: Bool) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        let color = categoryColor()
                        SubscriptionLogoView(
                            subscriptionId: group.subscriptionId,
                            logoURL: group.subscriptionLogoURL.flatMap(URL.init),
                            initials: firstLetter(for: group.name),
                            backgroundColor: color.opacity(colorScheme == .dark ? 0.25 : 0.16),
                            foregroundColor: color,
                            size: 26,
                            cornerRadius: 8
                        )
                        Text(group.name)
                            .font(.headline)
                    }
                    Text("Total: \(formattedCurrency(group.totalAmount)) / \(group.billingPeriod)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let estimatedTotal, group.currencyCode != preferredCurrencyCode {
                        Text("Estimado em \(preferredCurrencyCode): \(formattedCurrency(estimatedTotal, currencyCode: preferredCurrencyCode))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let nextChargeDate = nextChargeDate {
                        HStack(alignment: .center, spacing: 8) {
                            Text("Próxima cobrança: \(formattedDate(nextChargeDate))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                            if let chip = GroupRenewalChipView.model(for: group) {
                                GroupRenewalChipView(text: chip.text, color: chip.color)
                            }
                        }
                    }
                    if let payerName = currentPayerName {
                        Text("Pagador do mês: \(payerName)")
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
                    if showTopActions, canEdit {
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
                    if showTopActions {
                        Button {
                            shareCurrentCardSnapshot()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
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

                        if showMemberActions,
                           canEdit,
                           member.status != .paid,
                           member.status != .exempt,
                           member.userId != currentUserId {
                            HStack(spacing: 6) {
                                Button {
                                    Task {
                                        let usersStore = UsersStore()
                                        var phoneNumber: String?
                                        if let userId = member.userId {
                                            if let profile = try? await usersStore.fetchUserProfile(userId: userId) {
                                                phoneNumber = profile.phoneNumber
                                            }
                                        }

                                        let convertedAmount = estimatedMember(member.amount)
                                        let shouldConvert = group.currencyCode != preferredCurrencyCode
                                        let messageAmount = shouldConvert ? (convertedAmount ?? member.amount) : member.amount
                                        let messageCurrency = shouldConvert && convertedAmount != nil ? preferredCurrencyCode : group.currencyCode
                                        let originalAmount = (shouldConvert && convertedAmount != nil) ? member.amount : nil
                                        let originalCurrency = (shouldConvert && convertedAmount != nil) ? group.currencyCode : nil

                                        if let url = WhatsAppMessageBuilder.buildPaymentRequest(
                                            memberName: member.name,
                                            groupName: group.name,
                                            amount: messageAmount,
                                            currencyCode: messageCurrency,
                                            originalAmount: originalAmount,
                                            originalCurrencyCode: originalCurrency,
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

                                let markingPaid = isMarkingPaid(group.id, member.id)
                                Button {
                                    guard !markingPaid else { return }
                                    onMarkPaid(group.id, member.id)
                                } label: {
                                    ZStack {
                                        if markingPaid {
                                            ProgressView()
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "dollarsign")
                                                .font(.caption)
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(Color.green))
                                }
                                .buttonStyle(.plain)
                                .disabled(markingPaid)
                            }
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
        .shadow(color: includeShadow ? Color.black.opacity(0.06) : .clear, radius: 12, x: 0, y: 8)
    }

    @MainActor
    private func shareCurrentCardSnapshot() {
        let snapshot = cardContent(showTopActions: false, showMemberActions: false, includeShadow: false)
            .frame(width: 360)

        let renderer = ImageRenderer(content: snapshot)
        #if canImport(UIKit)
        renderer.scale = UIScreen.main.scale
        #endif
        guard let image = renderer.uiImage else { return }
        let hasConvertedValue = group.currencyCode != preferredCurrencyCode && estimatedTotal != nil
        let messageAmount = hasConvertedValue ? (estimatedTotal ?? group.totalAmount) : group.totalAmount
        let messageCurrency = hasConvertedValue ? preferredCurrencyCode : group.currencyCode
        let originalAmount = hasConvertedValue ? group.totalAmount : nil
        let originalCurrencyCode = hasConvertedValue ? group.currencyCode : nil
        let message = WhatsAppMessageBuilder.buildPaymentRequestMessage(
            memberName: "pessoal",
            groupName: group.name,
            amount: messageAmount,
            currencyCode: messageCurrency,
            originalAmount: originalAmount,
            originalCurrencyCode: originalCurrencyCode,
            pixKey: (group.pixKey?.isEmpty == false) ? group.pixKey : currentUserPixKey
        )
        sharePayload = SharePayload(items: [message, image])
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
        case .exempt:
            return .secondary
        }
    }

    private var currentPayerName: String? {
        guard group.paymentMode == .rotation else { return nil }
        let payerId = group.currentPayerId ?? group.rotationOrder.first
        guard let payerId else { return nil }
        let member = group.members.first { $0.id == payerId || $0.userId == payerId }
        let name = member?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? nil : name
    }

    private func firstLetter(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first.map { String($0).uppercased() } ?? "?"
    }

    private func categoryColor() -> Color {
        switch group.category {
        case .streaming:
            return Color(.systemIndigo)
        case .music:
            return Color(.systemPink)
        case .software:
            return Color(.systemTeal)
        case .housing:
            return Color(.systemOrange)
        case .utilities:
            return Color(.systemPurple)
        case .education:
            return Color(.systemBlue)
        case .fitness:
            return Color(.systemGreen)
        case .other:
            return Color(.systemGray)
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
