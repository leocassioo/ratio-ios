//
//  InvitesStore.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import FirebaseFirestore
import Foundation

final class InvitesStore {
    private let db = Firestore.firestore()

    func createInvite(
        groupId: String,
        groupName: String,
        createdBy: String,
        expiresAt: Date,
        maxUses: Int
    ) async throws -> String {
        let token = UUID().uuidString.lowercased()
        let data: [String: Any] = [
            "token": token,
            "groupId": groupId,
            "groupName": groupName,
            "createdBy": createdBy,
            "expiresAt": Timestamp(date: expiresAt),
            "maxUses": maxUses,
            "usesCount": 0,
            "status": "active",
            "createdAt": FieldValue.serverTimestamp()
        ]

        try await db.collection("groupInvites")
            .document(token)
            .setData(data)

        return token
    }
}
