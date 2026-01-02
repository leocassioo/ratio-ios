//
//  GroupsStore.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import FirebaseFirestore
import Foundation

final class GroupsStore {
    private let db = Firestore.firestore()

    func listenGroups(for userId: String, onChange: @escaping (Result<[Group], Error>) -> Void) -> ListenerRegistration {
        db.collection("groups")
            .whereField("memberIds", arrayContains: userId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                let groups = snapshot?.documents.compactMap(GroupMapper.group(from:)) ?? []
                onChange(.success(groups))
            }
    }

    func createGroup(data: [String: Any], members: [GroupMemberDraft], ownerId: String) async throws {
        let groupRef = db.collection("groups").document()
        let batch = db.batch()
        batch.setData(data, forDocument: groupRef)

        for member in members {
            let memberRef = groupRef.collection("members").document(member.id)
            let role = member.userId == ownerId ? "owner" : "member"
            let memberData: [String: Any] = [
                "name": member.name,
                "userId": member.userId as Any,
                "status": member.status.rawValue,
                "amount": member.amountValue,
                "role": role,
                "createdAt": FieldValue.serverTimestamp()
            ]
            batch.setData(memberData, forDocument: memberRef)
        }

        try await batch.commit()
    }
}
