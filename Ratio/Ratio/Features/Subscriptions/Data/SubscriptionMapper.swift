//
//  SubscriptionMapper.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import FirebaseFirestore
import Foundation

enum SubscriptionMapper {
    nonisolated static func item(from document: QueryDocumentSnapshot) -> SubscriptionItem? {
        let data = document.data()
        guard let name = data["name"] as? String else { return nil }

        let amount = data["amount"] as? Double ?? 0
        let currencyCode = data["currencyCode"] as? String ?? "BRL"
        let categoryRaw = data["category"] as? String ?? SubscriptionCategory.other.rawValue
        let category = SubscriptionCategory(rawValue: categoryRaw) ?? .other
        let periodRaw = data["period"] as? String ?? SubscriptionPeriod.monthly.rawValue
        let period = SubscriptionPeriod(rawValue: periodRaw) ?? .monthly
        let nextBillingTimestamp = data["nextBillingDate"] as? Timestamp
        let nextBillingDate = nextBillingTimestamp?.dateValue() ?? Date()
        let notes = data["notes"] as? String ?? ""

        return SubscriptionItem(
            id: document.documentID,
            name: name,
            amount: amount,
            currencyCode: currencyCode,
            category: category,
            period: period,
            nextBillingDate: nextBillingDate,
            notes: notes
        )
    }
}
