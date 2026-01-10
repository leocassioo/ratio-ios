//
//  GroupPaymentsStore.swift
//  Ratio
//
//  Created by Codex on 08/01/26.
//

import FirebaseFirestore
import FirebaseStorage
import Foundation

final class GroupPaymentsStore {
    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    func uploadReceipt(groupId: String, memberId: String, data: Data) async throws -> String {
        let filename = "\(UUID().uuidString).jpg"
        let ref = storage.reference().child("groups/\(groupId)/receipts/\(memberId)/\(filename)")
        _ = try await ref.putDataAsync(data)
        return try await ref.downloadURL().absoluteString
    }

    func submitPayment(groupId: String, memberId: String, receiptURL: String?) async throws {
        let groupRef = db.collection("groups").document(groupId)
        let memberRef = groupRef.collection("members").document(memberId)

        try await runTransaction { transaction in
            let groupSnapshot = try transaction.getDocument(groupRef)
            let updatedPreview = self.updatedMembersPreview(
                from: groupSnapshot,
                memberId: memberId,
                status: GroupMemberStatus.submitted.rawValue,
                receiptURL: receiptURL
            )

            var memberData: [String: Any] = [
                "status": GroupMemberStatus.submitted.rawValue,
                "updatedAt": FieldValue.serverTimestamp(),
                "submittedAt": FieldValue.serverTimestamp()
            ]
            if let receiptURL {
                memberData["receiptURL"] = receiptURL
            }

            transaction.updateData(memberData, forDocument: memberRef)
            transaction.updateData(["membersPreview": updatedPreview], forDocument: groupRef)
        }
    }

    func approvePayment(groupId: String, memberId: String) async throws {
        let groupRef = db.collection("groups").document(groupId)
        let memberRef = groupRef.collection("members").document(memberId)

        try await runTransaction { transaction in
            let groupSnapshot = try transaction.getDocument(groupRef)
            let updatedPreview = self.updatedMembersPreview(
                from: groupSnapshot,
                memberId: memberId,
                status: GroupMemberStatus.paid.rawValue,
                receiptURL: nil
            )

            let memberData: [String: Any] = [
                "status": GroupMemberStatus.paid.rawValue,
                "updatedAt": FieldValue.serverTimestamp(),
                "approvedAt": FieldValue.serverTimestamp()
            ]

            transaction.updateData(memberData, forDocument: memberRef)
            transaction.updateData(["membersPreview": updatedPreview], forDocument: groupRef)
        }
    }

    private func updatedMembersPreview(
        from snapshot: DocumentSnapshot,
        memberId: String,
        status: String,
        receiptURL: String?
    ) -> [[String: Any]] {
        let preview = (snapshot.data()?["membersPreview"] as? [[String: Any]])
            ?? (snapshot.data()?["members"] as? [[String: Any]] ?? [])
        return preview.map { member in
            guard let id = member["id"] as? String, id == memberId else {
                return member
            }

            var updated = member
            updated["status"] = status
            if let receiptURL {
                updated["receiptURL"] = receiptURL
            }
            return updated
        }
    }

    private func runTransaction(_ block: @escaping (Transaction) throws -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction({ transaction, errorPointer in
                do {
                    try block(transaction)
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }, completion: { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }
}
