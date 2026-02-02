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

    @discardableResult
    func markAsReadLocally(notificationId: String) -> Int {
        var unreadCount = 0
        sections = sections.map { section in
            let updatedItems = section.items.map { item -> NotificationItem in
                if item.id == notificationId {
                    return NotificationItem(
                        id: item.id,
                        title: item.title,
                        body: item.body,
                        route: item.route,
                        type: item.type,
                        data: item.data,
                        isRead: true,
                        createdAt: item.createdAt
                    )
                }
                return item
            }
            unreadCount += updatedItems.filter { !$0.isRead }.count
            return Section(title: section.title, items: updatedItems)
        }
        return unreadCount
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
