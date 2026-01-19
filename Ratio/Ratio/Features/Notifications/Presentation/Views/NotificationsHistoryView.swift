//
//  NotificationsHistoryView.swift
//  Ratio
//
//  Created by Codex on 24/02/26.
//

import SwiftUI

struct NotificationsHistoryView: View {
    private let todayItems: [NotificationHistoryItem] = [
        NotificationHistoryItem(
            id: "1",
            title: "Cobrança do grupo vence hoje",
            message: "Netflix Família vence hoje. Confira se todos já pagaram.",
            date: Date().addingTimeInterval(-60 * 10),
            route: .groups,
            isRead: false
        ),
        NotificationHistoryItem(
            id: "2",
            title: "Pagamento enviado",
            message: "João enviou o comprovante do grupo Spotify Duo.",
            date: Date().addingTimeInterval(-60 * 40),
            route: .groups,
            isRead: true
        )
    ]

    private let recentItems: [NotificationHistoryItem] = [
        NotificationHistoryItem(
            id: "3",
            title: "Assinatura renova amanhã",
            message: "ChatGPT Pro renova amanhã. Revise o valor estimado.",
            date: Date().addingTimeInterval(-60 * 60 * 24),
            route: .subscriptions,
            isRead: true
        ),
        NotificationHistoryItem(
            id: "4",
            title: "Novo grupo criado",
            message: "Você criou o grupo SetApp. Convide seus amigos.",
            date: Date().addingTimeInterval(-60 * 60 * 24 * 2),
            route: .groups,
            isRead: true
        )
    ]

    var body: some View {
        List {
            if !todayItems.isEmpty {
                Section("Hoje") {
                    ForEach(todayItems) { item in
                        Button {} label: {
                            NotificationHistoryRowView(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !recentItems.isEmpty {
                Section("Últimos dias") {
                    ForEach(recentItems) { item in
                        Button {} label: {
                            NotificationHistoryRowView(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Notificações")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        NotificationsHistoryView()
    }
}
