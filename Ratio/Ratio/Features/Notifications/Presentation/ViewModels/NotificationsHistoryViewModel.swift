//
//  NotificationsHistoryViewModel.swift
//  Ratio
//
//  Created by Codex on 24/02/26.
//

import FirebaseFirestore
import Foundation
import Combine

@MainActor
final class NotificationsHistoryViewModel: ObservableObject {
    struct Section: Identifiable {
        let id = UUID()
        let title: String
        let items: [NotificationItem]
    }

    @Published private(set) var sections: [Section] = []

    private let store: NotificationsStore
    private var listener: ListenerRegistration?

    init(store: NotificationsStore = NotificationsStore()) {
        self.store = store
    }

    func startListening(userId: String) {
        listener?.remove()
        listener = store.listenNotifications(for: userId) { [weak self] result in
            switch result {
            case .success(let items):
                self?.sections = Self.buildSections(from: items)
            case .failure:
                self?.sections = []
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func markAsRead(userId: String, notificationId: String) async {
        do {
            try await store.markAsRead(userId: userId, notificationId: notificationId)
        } catch {
            return
        }
    }

    func markAllAsRead(userId: String) async {
        do {
            try await store.markAllAsRead(userId: userId)
        } catch {
            return
        }
    }

    private static func buildSections(from items: [NotificationItem]) -> [Section] {
        guard !items.isEmpty else { return [] }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.createdAt)
        }
        let sortedKeys = grouped.keys.sorted(by: >)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd/MM/yyyy"

        return sortedKeys.map { date in
            let title: String
            if calendar.isDateInToday(date) {
                title = "Hoje"
            } else if calendar.isDateInYesterday(date) {
                title = "Ontem"
            } else {
                title = formatter.string(from: date)
            }
            let sectionItems = grouped[date]?.sorted(by: { $0.createdAt > $1.createdAt }) ?? []
            return Section(title: title, items: sectionItems)
        }
    }
}
