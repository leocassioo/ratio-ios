//
//  PaymentSubmissionView.swift
//  Ratio
//
//  Created by Codex on 08/01/26.
//

import PhotosUI
import SwiftUI
import UIKit

struct PaymentSubmissionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = GroupPaymentsViewModel()

    let groupId: String
    let memberId: String
    let amount: Double
    let currencyCode: String
    let onSubmitted: (() -> Void)?

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var receiptData: Data?

    var body: some View {
        Form {
            Section("Pagamento") {
                HStack {
                    Text("Valor")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formattedCurrency(amount, currencyCode: currencyCode))
                        .font(.headline)
                }
            }

            Section("Comprovante (opcional)") {
                VStack(alignment: .leading, spacing: 12) {
                    if let receiptData, let image = UIImage(data: receiptData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .clipped()
                            .cornerRadius(12)
                    }

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Selecionar comprovante", systemImage: "photo")
                    }
                }
            }

            Section {
                Button {
                    Task {
                        await viewModel.submitPayment(
                            groupId: groupId,
                            memberId: memberId,
                            receiptData: receiptData
                        )
                        if viewModel.errorMessage == nil {
                            onSubmitted?()
                            dismiss()
                        }
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Marcar como pago")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            if let message = viewModel.errorMessage {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Confirmar pagamento")
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else {
                receiptData = nil
                return
            }

            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        receiptData = data
                    }
                }
            }
        }
    }

    private func formattedCurrency(_ value: Double, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }
}
