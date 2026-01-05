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

    func updateSubscription(userId: String, id: String, data: [String: Any]) async throws {
        try await db.collection("users")
            .document(userId)
            .collection("subscriptions")
            .document(id)
            .setData(data, merge: true)
    }

    func updateLinkedGroups(subscriptionId: String, data: [String: Any]) async throws {
        let snapshot = try await db.collection("groups")
            .whereField("subscriptionId", isEqualTo: subscriptionId)
            .getDocuments()

        guard !snapshot.documents.isEmpty else { return }

        let batch = db.batch()
        snapshot.documents.forEach { document in
            batch.setData(data, forDocument: document.reference, merge: true)
        }
        try await batch.commit()
    }

    func updateLinkedGroupAmounts(subscriptionId: String, totalAmount: Double) async throws {
        let groupsSnapshot = try await db.collection("groups")
            .whereField("subscriptionId", isEqualTo: subscriptionId)
            .getDocuments()

        guard !groupsSnapshot.documents.isEmpty else { return }

        for groupDocument in groupsSnapshot.documents {
            let membersSnapshot = try await groupDocument.reference
                .collection("members")
                .getDocuments()

            let memberCount = max(membersSnapshot.documents.count, 1)
            let perMember = totalAmount / Double(memberCount)

            let batch = db.batch()
            membersSnapshot.documents.forEach { member in
                batch.updateData(["amount": perMember], forDocument: member.reference)
            }

            let membersPreview = membersSnapshot.documents
                .sorted { lhs, rhs in
                    let lhsRole = lhs.data()["role"] as? String ?? ""
                    let rhsRole = rhs.data()["role"] as? String ?? ""
                    if lhsRole == rhsRole {
                        let lhsName = lhs.data()["name"] as? String ?? ""
                        let rhsName = rhs.data()["name"] as? String ?? ""
                        return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
                    }
                    return lhsRole == "owner"
                }
                .map { member -> [String: Any] in
                let data = member.data()
                return [
                    "id": member.documentID,
                    "name": data["name"] as? String ?? "Membro",
                    "amount": perMember,
                    "status": data["status"] as? String ?? GroupMemberStatus.pending.rawValue,
                    "userId": data["userId"] as Any
                ]
            }

            batch.updateData([
                "membersPreview": membersPreview,
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: groupDocument.reference)

            try await batch.commit()
        }
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
