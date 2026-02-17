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

        var removedReceiptURLs: [String] = []
        try await runTransaction { transaction in
            let groupSnapshot = try transaction.getDocument(groupRef)
            let memberSnapshot = try transaction.getDocument(memberRef)
            let receiptUpdate = self.updatedReceiptHistory(from: memberSnapshot, receiptURL: receiptURL)
            let updatedHistory = receiptUpdate.history
            removedReceiptURLs = receiptUpdate.removedURLs
            let updatedPreview = self.updatedMembersPreview(
                from: groupSnapshot,
                memberId: memberId,
                status: GroupMemberStatus.submitted.rawValue,
                receiptURL: receiptURL,
                receiptHistory: updatedHistory
            )

            var memberData: [String: Any] = [
                "status": GroupMemberStatus.submitted.rawValue,
                "updatedAt": FieldValue.serverTimestamp(),
                "submittedAt": FieldValue.serverTimestamp()
            ]
            if let receiptURL {
                memberData["receiptURL"] = receiptURL
            }
            if !updatedHistory.isEmpty {
                memberData["receiptHistory"] = updatedHistory
            }

            transaction.updateData(memberData, forDocument: memberRef)
            transaction.updateData(["membersPreview": updatedPreview], forDocument: groupRef)
        }

        if !removedReceiptURLs.isEmpty {
            await deleteReceipts(urls: removedReceiptURLs)
        }
    }

    func approvePayment(groupId: String, memberId: String) async throws {
        let groupRef = db.collection("groups").document(groupId)
        let memberRef = groupRef.collection("members").document(memberId)

        try await runTransaction { transaction in
            let groupSnapshot = try transaction.getDocument(groupRef)
            let groupData = groupSnapshot.data() ?? [:]
            let updatedPreview = self.updatedMembersPreview(
                from: groupSnapshot,
                memberId: memberId,
                status: GroupMemberStatus.paid.rawValue,
                receiptURL: nil,
                receiptHistory: nil
            )

            let memberData: [String: Any] = [
                "status": GroupMemberStatus.paid.rawValue,
                "updatedAt": FieldValue.serverTimestamp(),
                "approvedAt": FieldValue.serverTimestamp()
            ]

            transaction.updateData(memberData, forDocument: memberRef)
            var groupUpdate: [String: Any] = ["membersPreview": updatedPreview]

            let paymentMode = (groupData["paymentMode"] as? String) ?? GroupPaymentMode.split.rawValue
            if paymentMode == GroupPaymentMode.rotation.rawValue {
                let rotationOrder = groupData["rotationOrder"] as? [String] ?? []
                let currentPayerId = groupData["currentPayerId"] as? String
                    ?? {
                        if let index = groupData["rotationIndex"] as? Int, index >= 0, index < rotationOrder.count {
                            return rotationOrder[index]
                        }
                        return rotationOrder.first
                    }()

                if let currentPayerId, currentPayerId == memberId, !rotationOrder.isEmpty {
                    let currentIndex = rotationOrder.firstIndex(of: currentPayerId) ?? 0
                    let nextIndex = (currentIndex + 1) % rotationOrder.count
                    let nextPayerId = rotationOrder[nextIndex]
                    groupUpdate["rotationIndex"] = nextIndex
                    groupUpdate["currentPayerId"] = nextPayerId
                    if let nextBilling = groupData["chargeNextBillingDate"] as? Timestamp
                        ?? groupData["subscriptionNextBillingDate"] as? Timestamp {
                        groupUpdate["rotationCycleStartDate"] = nextBilling
                    }
                }
            }

            transaction.updateData(groupUpdate, forDocument: groupRef)
        }
    }

    private func updatedMembersPreview(
        from snapshot: DocumentSnapshot,
        memberId: String,
        status: String,
        receiptURL: String?,
        receiptHistory: [[String: Any]]?
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
            if let receiptHistory {
                updated["receiptHistory"] = receiptHistory
            }
            return updated
        }
    }

    private func updatedReceiptHistory(from snapshot: DocumentSnapshot, receiptURL: String?) -> (history: [[String: Any]], removedURLs: [String]) {
        guard let receiptURL else { return ([], []) }
        let existing = snapshot.data()?["receiptHistory"] as? [[String: Any]] ?? []
        let entry: [String: Any] = [
            "id": UUID().uuidString,
            "url": receiptURL,
            "submittedAt": Timestamp(date: Date())
        ]
        let combined = [entry] + existing
        let trimmed = Array(combined.prefix(6))
        let removedURLs = combined.dropFirst(6).compactMap { $0["url"] as? String }
        return (trimmed, removedURLs)
    }

    private func deleteReceipts(urls: [String]) async {
        for url in urls {
            let ref = storage.reference(forURL: url)
            do {
                try await ref.delete()
            } catch {
                continue
            }
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
