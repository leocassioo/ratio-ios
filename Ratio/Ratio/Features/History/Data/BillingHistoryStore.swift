//
//  BillingHistoryStore.swift
//  Ratio
//
//  Created by Codex on 16/02/26.
//

import FirebaseFirestore
import Foundation

final class BillingHistoryStore {
    private let db = Firestore.firestore()

    func listenHistory(for userId: String, onChange: @escaping (Result<[BillingHistoryItem], Error>) -> Void) -> ListenerRegistration {
        db.collection("users")
            .document(userId)
            .collection("billingHistory")
            .order(by: "occurredAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                let items = snapshot?.documents.compactMap(BillingHistoryMapper.item(from:)) ?? []
                onChange(.success(items))
            }
    }
}
