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

    func createSubscription(userId: String, id: String, data: [String: Any]) async throws {
        try await db.collection("users")
            .document(userId)
            .collection("subscriptions")
            .document(id)
            .setData(data, merge: false)
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

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let subscriptionNextTimestamp = data["subscriptionNextBillingDate"] as? Timestamp

        let batch = db.batch()
        snapshot.documents.forEach { document in
            var updateData = data
            if let subscriptionNextTimestamp {
                let docData = document.data()
                let periodRaw = docData["subscriptionPeriod"] as? String
                let billingLabel = docData["billingPeriod"] as? String
                let period = SubscriptionPeriod(rawValue: periodRaw ?? "")
                    ?? (billingLabel.flatMap { SubscriptionPeriod.from(label: $0) })
                    ?? .monthly
                let chargeDay = docData["chargeDay"] as? Int ?? docData["billingDay"] as? Int
                let alignedDate = alignedChargeDate(
                    subscriptionNext: subscriptionNextTimestamp.dateValue(),
                    period: period,
                    billingDay: chargeDay,
                    today: today,
                    calendar: calendar
                )
                updateData["chargeNextBillingDate"] = Timestamp(date: alignedDate)
                updateData["updatedAt"] = FieldValue.serverTimestamp()
            }
            batch.setData(updateData, forDocument: document.reference, merge: true)
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

    private func alignedChargeDate(
        subscriptionNext: Date,
        period: SubscriptionPeriod,
        billingDay: Int?,
        today: Date,
        calendar: Calendar
    ) -> Date {
        let startOfToday = calendar.startOfDay(for: today)
        let baseDate = calendar.startOfDay(for: subscriptionNext)

        func adjustedDate(from reference: Date) -> Date {
            guard let billingDay, billingDay > 0 else {
                return calendar.startOfDay(for: reference)
            }
            var components = calendar.dateComponents([.year, .month], from: reference)
            let dayRange = calendar.range(of: .day, in: .month, for: reference)
            components.day = min(billingDay, dayRange?.count ?? billingDay)
            return calendar.date(from: components) ?? calendar.startOfDay(for: reference)
        }

        var candidate: Date
        if period == .weekly {
            candidate = baseDate
        } else {
            candidate = adjustedDate(from: baseDate)
        }

        while candidate < startOfToday {
            switch period {
            case .weekly:
                candidate = calendar.date(byAdding: .day, value: 7, to: candidate) ?? candidate
            case .monthly:
                candidate = calendar.date(byAdding: .month, value: 1, to: candidate) ?? candidate
                candidate = adjustedDate(from: candidate)
            case .quarterly:
                candidate = calendar.date(byAdding: .month, value: 3, to: candidate) ?? candidate
                candidate = adjustedDate(from: candidate)
            case .yearly:
                candidate = calendar.date(byAdding: .year, value: 1, to: candidate) ?? candidate
                candidate = adjustedDate(from: candidate)
            case .oneTime:
                return candidate
            }
        }

        return candidate
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
