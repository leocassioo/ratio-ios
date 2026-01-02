//
//  CreateSubscriptionView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI

struct CreateSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    @State private var name = ""
    @State private var amountText = ""
    @State private var amountValue: Double = 0
    @State private var currencyCode = "BRL"
    @State private var category: SubscriptionCategory = .streaming
    @State private var period: SubscriptionPeriod = .monthly
    @State private var nextBillingDate = Date()
    @State private var notes = ""

    let onSave: (SubscriptionItem) -> Void

    enum Field: Hashable {
        case amount
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
        .navigationTitle("Nova assinatura")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") {
                    let subscription = SubscriptionItem(
                        id: UUID().uuidString,
                        name: name,
                        amount: amountValue,
                        currencyCode: currencyCode,
                        category: category,
                        period: period,
                        nextBillingDate: nextBillingDate,
                        notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    onSave(subscription)
                    dismiss()
                }
                .disabled(!canSubmit)
            }
        }
        .onAppear {
            if amountValue > 0 {
                amountText = formatAmount(amountValue)
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
        CreateSubscriptionView { _ in }
    }
}
