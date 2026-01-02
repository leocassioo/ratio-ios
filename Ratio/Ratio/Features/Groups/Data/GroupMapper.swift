//
//  GroupMapper.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import FirebaseFirestore
import Foundation

enum GroupMapper {
    nonisolated static func group(from document: QueryDocumentSnapshot) -> Group? {
        let data = document.data()
        guard let name = data["name"] as? String else { return nil }

        let totalAmount = data["totalAmount"] as? Double ?? 0
        let categoryRaw = data["category"] as? String ?? GroupCategory.other.rawValue
        let category = GroupCategory(rawValue: categoryRaw) ?? .other
        let currencyCode = data["currencyCode"] as? String ?? "BRL"
        let billingPeriod = data["billingPeriod"] as? String ?? "mês"
        let billingDay = data["billingDay"] as? Int
        let notes = data["notes"] as? String
        let subscriptionId = data["subscriptionId"] as? String
        let subscriptionName = data["subscriptionName"] as? String
        let subscriptionPeriod = data["subscriptionPeriod"] as? String
        let subscriptionNextBilling = data["subscriptionNextBillingDate"] as? Timestamp
        let subscriptionNextBillingDate = subscriptionNextBilling?.dateValue()

        let membersData = (data["membersPreview"] as? [[String: Any]])
            ?? (data["members"] as? [[String: Any]] ?? [])

        let members = membersData.compactMap { memberData -> GroupMember? in
            let id = memberData["id"] as? String ?? UUID().uuidString
            let name = memberData["name"] as? String ?? "Membro"
            let amount = memberData["amount"] as? Double ?? 0
            let statusRaw = memberData["status"] as? String ?? GroupMemberStatus.pending.rawValue
            let status = GroupMemberStatus(rawValue: statusRaw) ?? .pending
            let userId = memberData["userId"] as? String
            return GroupMember(id: id, name: name, amount: amount, status: status, userId: userId)
        }

        return Group(
            id: document.documentID,
            name: name,
            category: category,
            totalAmount: totalAmount,
            currencyCode: currencyCode,
            billingPeriod: billingPeriod,
            billingDay: billingDay,
            notes: notes,
            subscriptionId: subscriptionId,
            subscriptionName: subscriptionName,
            subscriptionPeriod: subscriptionPeriod,
            subscriptionNextBillingDate: subscriptionNextBillingDate,
            members: members
        )
    }
}
