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

    func listenGroups(for userId: String, onChange: @escaping (Result<[SharedGroup], Error>) -> Void) -> ListenerRegistration {
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

    func fetchGroups(userId: String) async throws -> [SharedGroup] {
        let snapshot = try await db.collection("groups")
            .whereField("memberIds", arrayContains: userId)
            .getDocuments()
        return snapshot.documents.compactMap(GroupMapper.group(from:))
    }

    func createGroup(data: [String: Any], members: [GroupMemberDraft], ownerId: String) async throws -> String {
        let groupRef = db.collection("groups").document()
        try await groupRef.setData(data)

        let batch = db.batch()
        for member in members {
            let memberRef = groupRef.collection("members").document(member.id)
            let role = member.userId == ownerId ? "owner" : "member"
            let memberData: [String: Any] = [
                "name": member.name,
                "userId": member.userId as Any,
                "status": member.status.rawValue,
                "amount": member.amountValue,
                "photoURL": member.photoURL as Any,
                "receiptURL": member.receiptURL as Any,
                "role": role,
                "createdAt": FieldValue.serverTimestamp()
            ]
            batch.setData(memberData, forDocument: memberRef)
        }

        try await batch.commit()
        return groupRef.documentID
    }

    func updateGroup(groupId: String, data: [String: Any], members: [GroupMemberDraft], ownerId: String) async throws {
        let groupRef = db.collection("groups").document(groupId)
        let batch = db.batch()
        batch.setData(data, forDocument: groupRef, merge: true)

        let existingMembers = try await groupRef.collection("members").getDocuments()
        existingMembers.documents.forEach { document in
            batch.deleteDocument(document.reference)
        }

        for member in members {
            let memberRef = groupRef.collection("members").document(member.id)
            let role = member.userId == ownerId ? "owner" : "member"
            let memberData: [String: Any] = [
                "name": member.name,
                "userId": member.userId as Any,
                "status": member.status.rawValue,
                "amount": member.amountValue,
                "photoURL": member.photoURL as Any,
                "receiptURL": member.receiptURL as Any,
                "role": role,
                "createdAt": FieldValue.serverTimestamp()
            ]
            batch.setData(memberData, forDocument: memberRef)
        }

        try await batch.commit()
    }

    func deleteGroup(groupId: String) async throws {
        let groupRef = db.collection("groups").document(groupId)
        let batch = db.batch()

        let membersSnapshot = try await groupRef.collection("members").getDocuments()
        membersSnapshot.documents.forEach { document in
            batch.deleteDocument(document.reference)
        }

        batch.deleteDocument(groupRef)
        try await batch.commit()
    }

    func updateMemberPhoto(userId: String, photoURL: String?) async throws {
        let snapshot = try await db.collection("groups")
            .whereField("memberIds", arrayContains: userId)
            .getDocuments()

        guard !snapshot.documents.isEmpty else { return }

        let batch = db.batch()
        let photoValue: Any = photoURL ?? FieldValue.delete()

        for document in snapshot.documents {
            let data = document.data()
            let preview = (data["membersPreview"] as? [[String: Any]])
                ?? (data["members"] as? [[String: Any]] ?? [])

            let updatedPreview = preview.map { member in
                guard (member["userId"] as? String) == userId else {
                    return member
                }
                var updated = member
                if let photoURL {
                    updated["photoURL"] = photoURL
                } else {
                    updated.removeValue(forKey: "photoURL")
                }
                return updated
            }

            batch.updateData(["membersPreview": updatedPreview], forDocument: document.reference)

            let memberDocs = try await document.reference
                .collection("members")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()

            memberDocs.documents.forEach { memberDoc in
                batch.updateData(["photoURL": photoValue, "updatedAt": FieldValue.serverTimestamp()], forDocument: memberDoc.reference)
            }
        }

        try await batch.commit()
    }

    func normalizeChargeDates(for userId: String) async throws {
        let snapshot = try await db.collection("groups")
            .whereField("ownerId", isEqualTo: userId)
            .getDocuments()

        guard !snapshot.documents.isEmpty else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let batch = db.batch()

        for document in snapshot.documents {
            let data = document.data()
            guard let chargeTimestamp = data["chargeNextBillingDate"] as? Timestamp else { continue }
            let periodRaw = data["subscriptionPeriod"] as? String ?? SubscriptionPeriod.monthly.rawValue
            guard let period = SubscriptionPeriod(rawValue: periodRaw) else { continue }

            let currentDate = chargeTimestamp.dateValue()
            let nextDate = nextBillingDate(from: currentDate, period: period, today: today, calendar: calendar)
            if nextDate == currentDate {
                continue
            }

            batch.updateData([
                "chargeNextBillingDate": Timestamp(date: nextDate),
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: document.reference)
        }

        try await batch.commit()
    }

    private func nextBillingDate(
        from date: Date,
        period: SubscriptionPeriod,
        today: Date,
        calendar: Calendar
    ) -> Date {
        var nextDate = calendar.startOfDay(for: date)
        while nextDate < today {
            switch period {
            case .weekly:
                nextDate = calendar.date(byAdding: .day, value: 7, to: nextDate) ?? nextDate
            case .monthly:
                nextDate = calendar.date(byAdding: .month, value: 1, to: nextDate) ?? nextDate
            case .quarterly:
                nextDate = calendar.date(byAdding: .month, value: 3, to: nextDate) ?? nextDate
            case .yearly:
                nextDate = calendar.date(byAdding: .year, value: 1, to: nextDate) ?? nextDate
            }
        }
        return nextDate
    }
}
