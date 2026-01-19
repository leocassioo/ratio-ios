//
//  NotificationsBadgeViewModel.swift
//  Ratio
//
//  Created by Codex on 24/02/26.
//

import FirebaseFirestore
import Foundation
import Combine

@MainActor
final class NotificationsBadgeViewModel: ObservableObject {
    @Published private(set) var hasUnread = false

    private let store: NotificationsStore
    private var listener: ListenerRegistration?

    init(store: NotificationsStore = NotificationsStore()) {
        self.store = store
    }

    func startListening(userId: String) {
        listener?.remove()
        listener = store.listenUnreadCount(for: userId) { [weak self] result in
            switch result {
            case .success(let count):
                self?.hasUnread = count > 0
            case .failure:
                self?.hasUnread = false
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
