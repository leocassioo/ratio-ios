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
        photoURL: String?,
        pixKey: String?
    ) async throws {
        let data: [String: Any] = [
            "name": name,
            "email": email,
            "phoneNumber": phoneNumber,
            "photoURL": photoURL as Any,
            "pixKey": pixKey as Any,
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
        phoneNumber: String? = nil,
        photoURL: String?,
        pixKey: String?
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
        if let phoneNumber, !phoneNumber.isEmpty {
            data["phoneNumber"] = phoneNumber
        }
        if let photoURL {
            data["photoURL"] = photoURL
        }
        if let pixKey {
            data["pixKey"] = pixKey
        }

        try await db.collection("users")
            .document(userId)
            .setData(data, merge: true)
    }

    func fetchUserName(userId: String) async throws -> String? {
        let snapshot = try await db.collection("users").document(userId).getDocument()
        return snapshot.data()?["name"] as? String
    }

    func fetchUserProfile(userId: String) async throws -> UserProfile? {
        let snapshot = try await db.collection("users").document(userId).getDocument()
        let data = snapshot.data()
        guard let data else { return nil }
        return UserProfile(
            name: data["name"] as? String,
            email: data["email"] as? String,
            phoneNumber: data["phoneNumber"] as? String,
            photoURL: data["photoURL"] as? String,
            pixKey: data["pixKey"] as? String
        )
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
