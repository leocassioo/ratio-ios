//
//  NotificationsStore.swift
//  Ratio
//
//  Created by Codex on 24/02/26.
//

import FirebaseFirestore
import Foundation

final class NotificationsStore {
    private let db = Firestore.firestore()

    func listenNotifications(
        for userId: String,
        onChange: @escaping (Result<[NotificationItem], Error>) -> Void
    ) -> ListenerRegistration {
        db.collection("users")
            .document(userId)
            .collection("notifications")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                let items = snapshot?.documents.compactMap(NotificationMapper.item(from:)) ?? []
                onChange(.success(items))
            }
    }

    func listenUnreadCount(
        for userId: String,
        onChange: @escaping (Result<Int, Error>) -> Void
    ) -> ListenerRegistration {
        db.collection("users")
            .document(userId)
            .collection("notifications")
            .whereField("isRead", isEqualTo: false)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                onChange(.success(snapshot?.documents.count ?? 0))
            }
    }

    func markAsRead(userId: String, notificationId: String) async throws {
        try await db.collection("users")
            .document(userId)
            .collection("notifications")
            .document(notificationId)
            .updateData(["isRead": true])
    }

    func markAllAsRead(userId: String) async throws {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("notifications")
            .whereField("isRead", isEqualTo: false)
            .getDocuments()

        guard !snapshot.documents.isEmpty else { return }

        var batch = db.batch()
        var operations = 0

        for doc in snapshot.documents {
            batch.updateData(["isRead": true], forDocument: doc.reference)
            operations += 1

            if operations >= 450 {
                try await batch.commit()
                batch = db.batch()
                operations = 0
            }
        }

        if operations > 0 {
            try await batch.commit()
        }
    }
}
