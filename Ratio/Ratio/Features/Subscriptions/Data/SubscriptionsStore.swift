//
//  SubscriptionsStore.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import FirebaseFirestore
import Foundation

final class SubscriptionsStore {
    private let db = Firestore.firestore()

    func listenSubscriptions(for userId: String, onChange: @escaping (Result<[SubscriptionItem], Error>) -> Void) -> ListenerRegistration {
        db.collection("users")
            .document(userId)
            .collection("subscriptions")
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                let items = snapshot?.documents.compactMap(SubscriptionMapper.item(from:)) ?? []
                onChange(.success(items))
            }
    }

    func createSubscription(userId: String, data: [String: Any]) async throws {
        _ = try await db.collection("users")
            .document(userId)
            .collection("subscriptions")
            .addDocument(data: data)
    }

    func deleteSubscription(userId: String, id: String) async throws {
        try await db.collection("users")
            .document(userId)
            .collection("subscriptions")
            .document(id)
            .delete()
    }
}
