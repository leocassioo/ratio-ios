//
//  CreateSubscriptionView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import PhotosUI
import SwiftUI
import UIKit

struct CreateSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    private let analytics = AnalyticsService.shared
    let ownerId: String

    @State private var name = ""
    @State private var amountText = ""
    @State private var amountValue: Double = 0
    @State private var currencyCode = "BRL"
    @State private var category: SubscriptionCategory = .streaming
    @State private var period: SubscriptionPeriod = .monthly
    @State private var nextBillingDate = Date()
    @State private var notes = ""
    @State private var selectedLogoItem: PhotosPickerItem?
    @State private var selectedLogoImage: UIImage?
    @State private var selectedLogoURL: String?

    let onSave: (SubscriptionItem) -> Void

    enum Field: Hashable {
        case amount
    }

    var body: some View {
        Form {
            Section("Populares") {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(popularPresets) { preset in
                            Button {
                                applyPreset(preset)
                            } label: {
                                PopularSubscriptionPresetView(preset: preset)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section("Assinatura") {
                HStack(spacing: 10) {
                    TextField("Nome", text: $name)
                    logoPickerButton
                }

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
                    let subscriptionId = UUID().uuidString
                    Task {
                        var logoURL = selectedLogoURL
                        if let selectedLogoImage {
                            let uploadedURL = await SubscriptionLogoStore.shared.saveLogoAndUpload(
                                image: selectedLogoImage,
                                for: subscriptionId,
                                userId: ownerId
                            )
                            if let uploadedURL {
                                logoURL = uploadedURL
                            }
                        }
                        let subscription = SubscriptionItem(
                            id: subscriptionId,
                            name: name,
                            amount: amountValue,
                            currencyCode: currencyCode,
                            category: category,
                            period: period,
                            nextBillingDate: nextBillingDate,
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                            logoURL: logoURL
                        )
                        await MainActor.run {
                            onSave(subscription)
                            dismiss()
                        }
                    }
                }
                .disabled(!canSubmit)
            }
        }
        .onAppear {
            analytics.screenView(.screen_create_subscription)
            if amountValue > 0 {
                amountText = formatAmount(amountValue)
            }
        }
        .onChange(of: selectedLogoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        selectedLogoImage = image
                        selectedLogoURL = nil
                    }
                }
            }
        }
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amountValue > 0
    }

    private func applyPreset(_ preset: PopularSubscriptionPreset) {
        name = preset.name
        category = preset.category
        period = preset.period
        currencyCode = preset.currencyCode
        if let assetName = preset.assetName, let image = UIImage(named: assetName) {
            selectedLogoImage = image
            selectedLogoItem = nil
            selectedLogoURL = nil
        } else if let imageURL = preset.imageURL {
            selectedLogoImage = nil
            selectedLogoURL = imageURL.absoluteString
            selectedLogoItem = nil
        }

        if let suggestedAmount = preset.suggestedAmount,
           amountValue == 0,
           amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            amountValue = suggestedAmount
            amountText = formatAmount(suggestedAmount)
        }
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
            } else if let selectedLogoURL, let url = URL(string: selectedLogoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        InitialsBadgeView(
                            initials: initials,
                            backgroundColor: background,
                            foregroundColor: baseColor,
                            size: 48,
                            cornerRadius: 14
                        )
                    }
                }
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

    private var logoPreviewSmall: some View {
        return Group {
            if let selectedLogoImage {
                Image(uiImage: selectedLogoImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else if let selectedLogoURL, let url = URL(string: selectedLogoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            )
                    }
                }
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    )
            }
        }
    }

    private var logoPickerButton: some View {
        PhotosPicker(selection: $selectedLogoItem, matching: .images) {
            logoPreviewSmall
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(.separator).opacity(0.6), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Selecionar logo")
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

    private var popularPresets: [PopularSubscriptionPreset] {
        PopularSubscriptionPreset.presets(from: RemoteConfigService.shared.popularSubscriptionsPayload)
    }
}

#Preview {
    NavigationStack {
        CreateSubscriptionView(ownerId: "preview") { _ in }
    }
}
