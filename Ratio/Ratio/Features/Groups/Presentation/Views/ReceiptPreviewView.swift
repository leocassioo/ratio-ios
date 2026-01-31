//
//  ReceiptPreviewView.swift
//  Ratio
//
//  Created by Codex on 31/01/26.
//

import SwiftUI

struct ReceiptPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let receipt: ReceiptHistoryItem
    private var receiptURL: URL? { URL(string: receipt.url) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(formattedDate(receipt.submittedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let url = receiptURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 240)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .cornerRadius(12)
                        case .failure:
                            Text("Não foi possível carregar o comprovante.")
                                .foregroundStyle(.secondary)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Text("Link inválido.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Comprovante")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let url = receiptURL {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
}
