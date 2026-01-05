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
        let linkedGroups = try await db.collection("groups")
            .whereField("subscriptionId", isEqualTo: id)
            .getDocuments()

        if !linkedGroups.documents.isEmpty {
            throw SubscriptionDeletionError.linkedGroup
        }

        try await db.collection("users")
            .document(userId)
            .collection("subscriptions")
            .document(id)
            .delete()
    }
}

enum SubscriptionDeletionError: LocalizedError {
    case linkedGroup

    var errorDescription: String? {
        switch self {
        case .linkedGroup:
            return "Essa assinatura está vinculada a um grupo. Remova o vínculo antes de excluir."
        }
    }
}
