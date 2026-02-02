//
//  NotificationsHistoryView.swift
//  Ratio
//
//  Created by Codex on 24/02/26.
//

import SwiftUI
import FirebaseAuth

struct NotificationsHistoryView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = NotificationsHistoryViewModel()
    private let analytics = AnalyticsService.shared

    var body: some View {
        List {
            if viewModel.sections.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                        Text("Nenhuma notificação por enquanto")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }

            ForEach(viewModel.sections, id: \.title) { section in
                Section(section.title) {
                    ForEach(section.items) { item in
                        Button {
                            handleTap(item)
                        } label: {
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if hasUnread {
                    Button {
                        markAllAsRead()
                    }
                    label: {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .accessibilityLabel("Marcar todas como lidas")
                }
            }
        }
        .onAppear {
            analytics.screenView(.screen_notifications_history)
            analytics.track(.notification_history_open)
            if let userId = authViewModel.user?.uid {
                viewModel.startListening(userId: userId)
            }
        }
        .onChange(of: authViewModel.user?.uid) { _, newValue in
            guard let userId = newValue else { return }
            viewModel.startListening(userId: userId)
        }
        .onDisappear {
            viewModel.stopListening()
        }
    }

    private func handleTap(_ item: NotificationItem) {
        analytics.track(.notification_open, parameters: [
            "type": item.type,
            "route": item.route.rawValue
        ])
        let unreadCount = viewModel.markAsReadLocally(notificationId: item.id)
        NotificationManager.shared.updateBadge(count: unreadCount)
        if let userId = authViewModel.user?.uid {
            Task {
                await viewModel.markAsRead(userId: userId, notificationId: item.id)
            }
        }
        analytics.track(.notification_mark_read, parameters: [
            "type": item.type
        ])
        switch item.route {
        case .groups:
            router.route(to: .groups, groupId: item.data["groupId"])
        case .subscriptions:
            router.route(to: .subscriptions)
        case .home:
            router.route(to: .home)
        case .settings:
            router.route(to: .settings)
        }
    }

    private var hasUnread: Bool {
        viewModel.sections.contains { section in
            section.items.contains { !$0.isRead }
        }
    }

    private func markAllAsRead() {
        analytics.track(.notification_mark_read, parameters: ["bulk": true])
        guard let userId = authViewModel.user?.uid else { return }
        Task {
            await viewModel.markAllAsRead(userId: userId)
            NotificationManager.shared.updateBadge(count: 0)
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsHistoryView()
    }
}
