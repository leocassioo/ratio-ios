//
//  EditSubscriptionView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import PhotosUI
import SwiftUI
import UIKit

struct EditSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    private let analytics = AnalyticsService.shared

    @State private var name: String
    @State private var amountText: String
    @State private var amountValue: Double
    @State private var currencyCode: String
    @State private var category: SubscriptionCategory
    @State private var period: SubscriptionPeriod
    @State private var nextBillingDate: Date
    @State private var notes: String
    @State private var selectedLogoItem: PhotosPickerItem?
    @State private var selectedLogoImage: UIImage?

    let subscriptionId: String
    let canDelete: Bool
    let onDelete: () -> Void
    let onSave: (SubscriptionItem) -> Void
    @State private var showDeleteConfirm = false

    enum Field: Hashable {
        case amount
    }

    init(
        subscription: SubscriptionItem,
        canDelete: Bool = false,
        onDelete: @escaping () -> Void = {},
        onSave: @escaping (SubscriptionItem) -> Void
    ) {
        self.subscriptionId = subscription.id
        _name = State(initialValue: subscription.name)
        _amountValue = State(initialValue: subscription.amount)
        _amountText = State(initialValue: subscription.amount.formatted(.number.precision(.fractionLength(2))))
        _currencyCode = State(initialValue: subscription.currencyCode)
        _category = State(initialValue: subscription.category)
        _period = State(initialValue: subscription.period)
        _nextBillingDate = State(initialValue: subscription.nextBillingDate)
        _notes = State(initialValue: subscription.notes)
        self.canDelete = canDelete
        self.onDelete = onDelete
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Logo") {
                PhotosPicker(selection: $selectedLogoItem, matching: .images) {
                    HStack(spacing: 12) {
                        logoPreview

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Atualizar logo")
                                .font(.subheadline.weight(.semibold))
                            Text("Opcional")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Assinatura") {
                TextField("Nome", text: $name)

                HStack {
                    Text(currencySymbol)
                        .foregroundStyle(.secondary)
                    TextField("0,00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .amount)
                        .onChange(of: amountText) { _, newValue in
                            let sanitized = AmountInputFormatter.sanitize(newValue)
                            if sanitized != newValue {
                                amountText = sanitized
                                return
                            }
                            if let value = parseAmount(sanitized) {
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
                    Text("EUR").tag("EUR")
                }

                Picker("Tipo", selection: $category) {
                    ForEach(SubscriptionCategory.allCases) { category in
                        Text(category.label).tag(category)
                    }
                }

                Picker("Periodicidade", selection: $period) {
                    ForEach(SubscriptionPeriod.allCases.filter { $0 != .oneTime }) { period in
                        Text(period.label).tag(period)
                    }
                }

                DatePicker("Próxima cobrança", selection: $nextBillingDate, displayedComponents: .date)
            }

            Section("Observações") {
                TextField("Detalhes", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }

            Section {
                if canDelete {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Text("Excluir assinatura")
                    }
                } else {
                    Text("Esta assinatura está vinculada a um grupo e não pode ser excluída.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
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
                    if let selectedLogoImage {
                        SubscriptionLogoStore.shared.saveLogo(image: selectedLogoImage, for: subscriptionId)
                    }
                    onSave(updated)
                    dismiss()
                }
                .disabled(!canSubmit)
            }
        }
        .alert("Excluir assinatura", isPresented: $showDeleteConfirm) {
            Button("Cancelar", role: .cancel) {}
            Button("Excluir", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("Tem certeza que deseja excluir esta assinatura? Essa ação não pode ser desfeita.")
        }
        .onAppear {
            analytics.screenView(.screen_edit_subscription)
            if let existing = SubscriptionLogoStore.shared.loadLogo(for: subscriptionId) {
                selectedLogoImage = existing
            }
        }
        .onChange(of: selectedLogoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedLogoImage = image
                }
            }
        }
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amountValue > 0
    }

    private func parseAmount(_ text: String) -> Double? {
        AmountInputFormatter.parse(text)
    }

    private func formatAmount(_ value: Double) -> String {
        AmountInputFormatter.format(value)
    }

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.currencySymbol
    }

    private var logoPreview: some View {
        let initials = InitialsBadgeView.initials(for: name.isEmpty ? "?" : name)
        let baseColor = categoryColor()
        let background = baseColor.opacity(0.16)
        return Group {
            if let selectedLogoImage {
                Image(uiImage: selectedLogoImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                InitialsBadgeView(
                    initials: initials,
                    backgroundColor: background,
                    foregroundColor: baseColor,
                    size: 48,
                    cornerRadius: 14
                )
            }
        }
    }

    private func categoryColor() -> Color {
        switch category {
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
            canDelete: true,
            onDelete: {},
            onSave: { _ in }
        )
    }
}
