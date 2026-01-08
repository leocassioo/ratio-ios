//
//  UsersStore.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import FirebaseFirestore
import Foundation

final class UsersStore {
    private lazy var db = Firestore.firestore()

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

    func updateUserProfile(
        userId: String,
        name: String?,
        email: String?,
        photoURL: String?
    ) async throws {
        var data: [String: Any] = [
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let name, !name.isEmpty {
            data["name"] = name
        }
        if let email, !email.isEmpty {
            data["email"] = email
        }
        if let photoURL {
            data["photoURL"] = photoURL
        }

        try await db.collection("users")
            .document(userId)
            .setData(data, merge: true)
    }

    func fetchUserName(userId: String) async throws -> String? {
        let snapshot = try await db.collection("users").document(userId).getDocument()
        return snapshot.data()?["name"] as? String
    }

    func updateFCMToken(userId: String, token: String) async throws {
        let data: [String: Any] = [
            "fcmTokens": FieldValue.arrayUnion([token]),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await db.collection("users")
            .document(userId)
            .setData(data, merge: true)
    }
}
