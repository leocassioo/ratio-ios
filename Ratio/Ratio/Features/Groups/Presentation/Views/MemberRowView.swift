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
    let isAmountEditable: Bool
    let isStatusEditable: Bool
    @Binding var memberValues: [String: Double]
    let parseAmount: (String) -> Double?
    let formatAmount: (Double) -> String
    let sanitizeAmount: (String) -> String
    @FocusState private var isAmountFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Nome", text: $member.name)
            HStack {
                Text(currencySymbol)
                    .foregroundStyle(.secondary)
                TextField("0,00", text: $member.amountText)
                    .keyboardType(.decimalPad)
                    .disabled(!isAmountEditable)
                    .focused($isAmountFocused)
                    .onChange(of: member.amountText) { _, newValue in
                        if splitEqually { return }
                        if !isAmountEditable { return }
                        let sanitized = sanitizeAmount(newValue)
                        if sanitized != newValue {
                            member.amountText = sanitized
                            return
                        }
                        if let value = parseAmount(sanitized) {
                            member.amountText = sanitized
                            memberValues[member.id] = value
                        } else if newValue.isEmpty {
                            memberValues[member.id] = 0
                        }
                    }
                    .onChange(of: isAmountFocused) { _, newValue in
                        if !newValue, let value = parseAmount(member.amountText) {
                            member.amountText = formatAmount(value)
                            memberValues[member.id] = value
                        }
                    }
            }

            if isStatusEditable {
                Picker("Status", selection: $member.status) {
                    ForEach(GroupMemberStatus.editableCases, id: \.self) { status in
                        Text(status.label).tag(status)
                    }
                }
            } else {
                HStack {
                    Text("Status")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(member.status.label)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
