//
//  EditSubscriptionView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI

struct EditSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    @State private var name: String
    @State private var amountText: String
    @State private var amountValue: Double
    @State private var currencyCode: String
    @State private var category: SubscriptionCategory
    @State private var period: SubscriptionPeriod
    @State private var nextBillingDate: Date
    @State private var notes: String

    let subscriptionId: String
    let onSave: (SubscriptionItem) -> Void

    enum Field: Hashable {
        case amount
    }

    init(subscription: SubscriptionItem, onSave: @escaping (SubscriptionItem) -> Void) {
        self.subscriptionId = subscription.id
        _name = State(initialValue: subscription.name)
        _amountValue = State(initialValue: subscription.amount)
        _amountText = State(initialValue: subscription.amount.formatted(.number.precision(.fractionLength(2))))
        _currencyCode = State(initialValue: subscription.currencyCode)
        _category = State(initialValue: subscription.category)
        _period = State(initialValue: subscription.period)
        _nextBillingDate = State(initialValue: subscription.nextBillingDate)
        _notes = State(initialValue: subscription.notes)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Assinatura") {
                TextField("Nome", text: $name)

                HStack {
                    Text(currencySymbol)
                        .foregroundStyle(.secondary)
                    TextField("0,00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .amount)
                        .onChange(of: amountText) { _, newValue in
                            if let value = parseAmount(newValue) {
                                amountValue = value
                            } else if newValue.isEmpty {
                                amountValue = 0
                            }
                        }
                        .onChange(of: focusedField) { oldValue, newValue in
                            if oldValue == .amount && newValue != .amount {
                                amountText = formatAmount(amountValue)
                            }
                        }
                }

                Picker("Moeda", selection: $currencyCode) {
                    Text("BRL").tag("BRL")
                    Text("USD").tag("USD")
                }

                Picker("Tipo", selection: $category) {
                    ForEach(SubscriptionCategory.allCases) { category in
                        Text(category.label).tag(category)
                    }
                }

                Picker("Periodicidade", selection: $period) {
                    ForEach(SubscriptionPeriod.allCases) { period in
                        Text(period.label).tag(period)
                    }
                }

                DatePicker("Próxima cobrança", selection: $nextBillingDate, displayedComponents: .date)
            }

            Section("Observações") {
                TextField("Detalhes", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
        }
        .navigationTitle("Editar assinatura")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") {
                    let updated = SubscriptionItem(
                        id: subscriptionId,
                        name: name,
                        amount: amountValue,
                        currencyCode: currencyCode,
                        category: category,
                        period: period,
                        nextBillingDate: nextBillingDate,
                        notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    onSave(updated)
                    dismiss()
                }
                .disabled(!canSubmit)
            }
        }
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amountValue > 0
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
        EditSubscriptionView(
            subscription: SubscriptionItem(
                id: "preview",
                name: "Netflix",
                amount: 55.9,
                currencyCode: "BRL",
                category: .streaming,
                period: .monthly,
                nextBillingDate: Date(),
                notes: ""
            ),
            onSave: { _ in }
        )
    }
}
