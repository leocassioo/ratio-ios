//
//  UsersStore.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import FirebaseFirestore
import Foundation

final class UsersStore {
    private let db = Firestore.firestore()

    func upsertUser(
        userId: String,
        name: String,
        email: String,
        phoneNumber: String,
        photoURL: String?
    ) async throws {
        let data: [String: Any] = [
            "name": name,
            "email": email,
            "phoneNumber": phoneNumber,
            "photoURL": photoURL as Any,
            "updatedAt": FieldValue.serverTimestamp(),
            "createdAt": FieldValue.serverTimestamp()
        ]

        try await db.collection("users")
            .document(userId)
            .setData(data, merge: true)
    }
}
