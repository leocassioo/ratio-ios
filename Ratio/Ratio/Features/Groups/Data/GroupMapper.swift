//
//  GroupMapper.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import FirebaseFirestore
import Foundation

enum GroupMapper {
    nonisolated static func group(from document: QueryDocumentSnapshot) -> SharedGroup? {
        let data = document.data()
        guard let name = data["name"] as? String else { return nil }

        let totalAmount = data["totalAmount"] as? Double ?? 0
        let categoryRaw = data["category"] as? String ?? GroupCategory.other.rawValue
        let category = GroupCategory(rawValue: categoryRaw) ?? .other
        let currencyCode = data["currencyCode"] as? String ?? "BRL"
        let billingPeriod = data["billingPeriod"] as? String ?? "mês"
        let billingDay = data["billingDay"] as? Int
        let notes = data["notes"] as? String
        let ownerId = data["ownerId"] as? String
        let ownerPhoneNumber = data["ownerPhoneNumber"] as? String
        let subscriptionId = data["subscriptionId"] as? String
        let subscriptionName = data["subscriptionName"] as? String
        let subscriptionCategory = data["subscriptionCategory"] as? String
        let subscriptionPeriod = data["subscriptionPeriod"] as? String
        let subscriptionNextBilling = data["subscriptionNextBillingDate"] as? Timestamp
        let subscriptionNextBillingDate = subscriptionNextBilling?.dateValue()
        let subscriptionLogoURL = data["subscriptionLogoURL"] as? String
        let chargeDay = data["chargeDay"] as? Int
        let chargeNextBilling = data["chargeNextBillingDate"] as? Timestamp
        let chargeNextBillingDate = chargeNextBilling?.dateValue()
        let serviceLogin = data["serviceLogin"] as? String
        let servicePassword = data["servicePassword"] as? String
        let pixKey = data["pixKey"] as? String

        let membersData = (data["membersPreview"] as? [[String: Any]])
            ?? (data["members"] as? [[String: Any]] ?? [])

        var seenMemberKeys = Set<String>()
        let members = membersData.compactMap { memberData -> GroupMember? in
            let userId = memberData["userId"] as? String
            let name = memberData["name"] as? String ?? "Membro"
            let id = memberData["id"] as? String ?? userId ?? UUID().uuidString
            let amount = memberData["amount"] as? Double ?? 0
            let statusRaw = memberData["status"] as? String ?? GroupMemberStatus.pending.rawValue
            let status = GroupMemberStatus(rawValue: statusRaw) ?? .pending
            let dedupeKey = userId ?? id
            guard !seenMemberKeys.contains(dedupeKey) else { return nil }
            seenMemberKeys.insert(dedupeKey)
            let photoURL = memberData["photoURL"] as? String
            let receiptURL = memberData["receiptURL"] as? String
            let receiptHistoryData = memberData["receiptHistory"] as? [[String: Any]] ?? []
            let receiptHistory = receiptHistoryData.compactMap { entry -> ReceiptHistoryItem? in
                guard let url = entry["url"] as? String else { return nil }
                let submittedAt = (entry["submittedAt"] as? Timestamp)?.dateValue() ?? Date()
                let id = entry["id"] as? String ?? UUID().uuidString
                return ReceiptHistoryItem(id: id, url: url, submittedAt: submittedAt)
            }
            let submittedAtTimestamp = memberData["submittedAt"] as? Timestamp
            let approvedAtTimestamp = memberData["approvedAt"] as? Timestamp
            return GroupMember(
                id: id,
                name: name,
                amount: amount,
                status: status,
                userId: userId,
                photoURL: photoURL,
                receiptURL: receiptURL,
                receiptHistory: receiptHistory,
                submittedAt: submittedAtTimestamp?.dateValue(),
                approvedAt: approvedAtTimestamp?.dateValue()
            )
        }

        return SharedGroup(
            id: document.documentID,
            name: name,
            category: category,
            totalAmount: totalAmount,
            currencyCode: currencyCode,
            billingPeriod: billingPeriod,
            billingDay: billingDay,
            notes: notes,
            ownerId: ownerId,
            ownerPhoneNumber: ownerPhoneNumber,
            subscriptionId: subscriptionId,
            subscriptionName: subscriptionName,
            subscriptionCategory: subscriptionCategory,
            subscriptionPeriod: subscriptionPeriod,
            subscriptionNextBillingDate: subscriptionNextBillingDate,
            subscriptionLogoURL: subscriptionLogoURL,
            chargeDay: chargeDay,
            chargeNextBillingDate: chargeNextBillingDate,
            serviceLogin: serviceLogin,
            servicePassword: servicePassword,
            pixKey: pixKey,
            members: members
        )
    }
}
