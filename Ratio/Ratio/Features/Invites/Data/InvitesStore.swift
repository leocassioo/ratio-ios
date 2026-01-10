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
        let groupSnapshot = try await db.collection("groups").document(groupId).getDocument()
        let groupData = groupSnapshot.data() ?? [:]
        let memberIds = groupData["memberIds"] as? [String] ?? []
        let membersPreview = groupData["membersPreview"] as? [[String: Any]] ?? []
        let totalAmount = groupData["totalAmount"] as? Double ?? 0

        let token = UUID().uuidString.lowercased()
        let data: [String: Any] = [
            "token": token,
            "groupId": groupId,
            "groupName": groupName,
            "createdBy": createdBy,
            "totalAmount": totalAmount,
            "memberCount": memberIds.count,
            "membersPreview": membersPreview,
            "memberIds": memberIds,
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

    func fetchInvite(token: String) async throws -> InviteInfo {
        let snapshot = try await db.collection("groupInvites").document(token).getDocument()
        guard let data = snapshot.data(),
              let groupId = data["groupId"] as? String,
              let groupName = data["groupName"] as? String,
              let createdBy = data["createdBy"] as? String,
              let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue(),
              let maxUses = data["maxUses"] as? Int,
              let usesCount = data["usesCount"] as? Int,
              let status = data["status"] as? String else {
            throw InviteError.invalid
        }

        return InviteInfo(
            id: token,
            groupId: groupId,
            groupName: groupName,
            createdBy: createdBy,
            expiresAt: expiresAt,
            maxUses: maxUses,
            usesCount: usesCount,
            status: status
        )
    }

    func acceptInvite(token: String, userId: String, userName: String) async throws {
        let inviteRef = db.collection("groupInvites").document(token)
        let inviteSnapshot = try await inviteRef.getDocument()
        guard let inviteData = inviteSnapshot.data(),
              let groupId = inviteData["groupId"] as? String,
              let expiresAt = (inviteData["expiresAt"] as? Timestamp)?.dateValue(),
              let maxUses = inviteData["maxUses"] as? Int,
              let usesCount = inviteData["usesCount"] as? Int,
              let status = inviteData["status"] as? String else {
            throw InviteError.invalid
        }

        guard status == "active" else { throw InviteError.alreadyUsed }
        guard Date() < expiresAt else { throw InviteError.expired }
        guard usesCount < maxUses else { throw InviteError.alreadyUsed }

        let groupRef = db.collection("groups").document(groupId)
        let memberIds = inviteData["memberIds"] as? [String] ?? []
        if memberIds.contains(userId) {
            throw InviteError.alreadyMember
        }

        let totalAmount = inviteData["totalAmount"] as? Double ?? 0
        let existingCount = inviteData["memberCount"] as? Int ?? memberIds.count
        let newMemberCount = max(existingCount, memberIds.count) + 1
        let perMember = newMemberCount > 0 ? totalAmount / Double(newMemberCount) : 0

        let batch = db.batch()
        let newMemberRef = groupRef.collection("members").document(userId)
        let newMemberData: [String: Any] = [
            "name": userName,
            "userId": userId,
            "status": GroupMemberStatus.pending.rawValue,
            "amount": perMember,
            "role": "member",
            "createdAt": FieldValue.serverTimestamp()
        ]
        batch.setData(newMemberData, forDocument: newMemberRef)

        let existingPreview = inviteData["membersPreview"] as? [[String: Any]] ?? []
        let updatedPreview = existingPreview.map { member in
            var updated = member
            updated["amount"] = perMember
            return updated
        }
        let membersPreview: [[String: Any]] = updatedPreview + [[
            "id": userId,
            "name": userName,
            "amount": perMember,
            "status": GroupMemberStatus.pending.rawValue,
            "userId": userId
        ]]

        batch.updateData([
            "membersPreview": membersPreview,
            "memberIds": FieldValue.arrayUnion([userId]),
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: groupRef)

        let newUsesCount = usesCount + 1
        let inviteStatus = newUsesCount >= maxUses ? "used" : "active"
        batch.updateData([
            "usesCount": newUsesCount,
            "status": inviteStatus,
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: inviteRef)

        try await batch.commit()
    }
}
