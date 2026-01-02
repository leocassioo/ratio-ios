//
//  MemberRowView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI

struct MemberRowView: View {
    @Binding var member: GroupMemberDraft
    let currencySymbol: String
    let splitEqually: Bool
    @FocusState.Binding var focusedField: CreateGroupView.Field?
    @Binding var memberValues: [String: Double]
    let parseAmount: (String) -> Double?
    let formatAmount: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Nome", text: $member.name)
            HStack {
                Text(currencySymbol)
                    .foregroundStyle(.secondary)
                TextField("0,00", text: $member.amountText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .memberAmount(member.id))
                    .onChange(of: member.amountText) { _, newValue in
                        if splitEqually { return }
                        if let value = parseAmount(newValue) {
                            member.amountText = newValue
                            memberValues[member.id] = value
                        } else if newValue.isEmpty {
                            memberValues[member.id] = 0
                        }
                    }
                    .onChange(of: focusedField) { oldValue, newValue in
                        if oldValue == .memberAmount(member.id) && newValue != .memberAmount(member.id) {
                            if let value = parseAmount(member.amountText) {
                                member.amountText = formatAmount(value)
                                memberValues[member.id] = value
                            }
                        }
                    }
            }

            Picker("Status", selection: $member.status) {
                ForEach(GroupMemberStatus.allCases, id: \.self) { status in
                    Text(status.label).tag(status)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
