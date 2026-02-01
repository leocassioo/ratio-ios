//
//  ReceiptHistorySheetView.swift
//  Ratio
//
//  Created by Codex on 30/01/26.
//

import SwiftUI

struct ReceiptHistorySheetView: View {
    @Environment(\.dismiss) private var dismiss
    let memberName: String
    let groupId: String
    let memberId: String
    let receipts: [ReceiptHistoryItem]
    private let analytics = AnalyticsService.shared

    var body: some View {
        NavigationStack {
            List {
                if receipts.isEmpty {
                    Text("Nenhum comprovante disponível.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(receipts) { receipt in
                        NavigationLink(value: AppRoute.receiptPreview(receipt: receipt, groupId: groupId, memberId: memberId)) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(formattedDate(receipt.submittedAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Ver comprovante")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Comprovantes")
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .receiptPreview(let receipt, let groupId, let memberId):
                    ReceiptPreviewView(receipt: receipt, groupId: groupId, memberId: memberId)
                default:
                    EmptyView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                HStack {
                    Text(memberName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            analytics.screenView(.screen_receipt_history)
            analytics.track(.receipt_history_open, parameters: [
                "group_id": groupId,
                "member_id": memberId
            ])
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
}
