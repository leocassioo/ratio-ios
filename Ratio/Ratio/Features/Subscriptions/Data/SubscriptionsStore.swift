//
//  SubscriptionsStore.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import FirebaseFirestore
import Foundation

final class SubscriptionsStore {
    private let db = Firestore.firestore()

    func listenSubscriptions(for userId: String, onChange: @escaping (Result<[SubscriptionItem], Error>) -> Void) -> ListenerRegistration {
        db.collection("users")
            .document(userId)
            .collection("subscriptions")
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                let items = snapshot?.documents.compactMap(SubscriptionMapper.item(from:)) ?? []
                onChange(.success(items))
            }
    }

    func fetchSubscriptions(userId: String) async throws -> [SubscriptionItem] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("subscriptions")
            .getDocuments()
        return snapshot.documents.compactMap(SubscriptionMapper.item(from:))
    }

    func createSubscription(userId: String, data: [String: Any]) async throws {
        _ = try await db.collection("users")
            .document(userId)
            .collection("subscriptions")
            .addDocument(data: data)
    }

    func updateSubscription(userId: String, id: String, data: [String: Any]) async throws {
        try await db.collection("users")
            .document(userId)
            .collection("subscriptions")
            .document(id)
            .setData(data, merge: true)
    }

    func updateLinkedGroups(subscriptionId: String, ownerId: String, data: [String: Any]) async throws {
        let snapshot = try await db.collection("groups")
            .whereField("subscriptionId", isEqualTo: subscriptionId)
            .whereField("ownerId", isEqualTo: ownerId)
            .getDocuments()

        guard !snapshot.documents.isEmpty else { return }

        let batch = db.batch()
        snapshot.documents.forEach { document in
            batch.setData(data, forDocument: document.reference, merge: true)
        }
        try await batch.commit()
    }

    func updateLinkedGroupAmounts(subscriptionId: String, ownerId: String, totalAmount: Double) async throws {
        let groupsSnapshot = try await db.collection("groups")
            .whereField("subscriptionId", isEqualTo: subscriptionId)
            .whereField("ownerId", isEqualTo: ownerId)
            .getDocuments()

        guard !groupsSnapshot.documents.isEmpty else { return }

        for groupDocument in groupsSnapshot.documents {
            let membersSnapshot = try await groupDocument.reference
                .collection("members")
                .getDocuments()

            let memberCount = max(membersSnapshot.documents.count, 1)
            let perMember = totalAmount / Double(memberCount)

            let batch = db.batch()
            membersSnapshot.documents.forEach { member in
                batch.updateData(["amount": perMember], forDocument: member.reference)
            }

            let membersPreview = membersSnapshot.documents
                .sorted { lhs, rhs in
                    let lhsRole = lhs.data()["role"] as? String ?? ""
                    let rhsRole = rhs.data()["role"] as? String ?? ""
                    if lhsRole == rhsRole {
                        let lhsName = lhs.data()["name"] as? String ?? ""
                        let rhsName = rhs.data()["name"] as? String ?? ""
                        return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
                    }
                    return lhsRole == "owner"
                }
                .map { member -> [String: Any] in
                let data = member.data()
                return [
                    "id": member.documentID,
                    "name": data["name"] as? String ?? "Membro",
                    "amount": perMember,
                    "status": data["status"] as? String ?? GroupMemberStatus.pending.rawValue,
                    "userId": data["userId"] as Any
                ]
            }

            batch.updateData([
                "membersPreview": membersPreview,
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: groupDocument.reference)

            try await batch.commit()
        }
    }

    func deleteSubscription(userId: String, id: String) async throws {
        let linkedGroups = try await db.collection("groups")
            .whereField("subscriptionId", isEqualTo: id)
            .whereField("ownerId", isEqualTo: userId)
            .getDocuments()

        if !linkedGroups.documents.isEmpty {
            throw SubscriptionDeletionError.linkedGroup
        }

        try await db.collection("users")
            .document(userId)
            .collection("subscriptions")
            .document(id)
            .delete()
    }

    func normalizeNextBillingDates(userId: String) async throws {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("subscriptions")
            .getDocuments()

        guard !snapshot.documents.isEmpty else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let batch = db.batch()

        for document in snapshot.documents {
            let data = document.data()
            guard let timestamp = data["nextBillingDate"] as? Timestamp else { continue }
            let periodRaw = data["period"] as? String ?? SubscriptionPeriod.monthly.rawValue
            guard let period = SubscriptionPeriod(rawValue: periodRaw) else { continue }

            let currentDate = timestamp.dateValue()
            let nextDate = nextBillingDate(from: currentDate, period: period, today: today, calendar: calendar)
            if nextDate == currentDate {
                continue
            }

            batch.updateData([
                "nextBillingDate": Timestamp(date: nextDate),
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: document.reference)

            try await updateLinkedGroups(
                subscriptionId: document.documentID,
                ownerId: userId,
                data: [
                    "subscriptionNextBillingDate": Timestamp(date: nextDate),
                    "updatedAt": FieldValue.serverTimestamp()
                ]
            )
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
            case .oneTime:
                return nextDate
            }
        }
        return nextDate
    }
}

enum SubscriptionDeletionError: LocalizedError {
    case linkedGroup

    var errorDescription: String? {
        switch self {
        case .linkedGroup:
            return "Essa assinatura está vinculada a um grupo. Remova o vínculo antes de excluir."
        }
    }
}
