//
//  BillingHistoryMapper.swift
//  Ratio
//
//  Created by Codex on 16/02/26.
//

import FirebaseFirestore
import Foundation

enum BillingHistoryMapper {
    static func item(from document: QueryDocumentSnapshot) -> BillingHistoryItem? {
        let data = document.data()
        guard let title = data["title"] as? String,
              let amount = data["amount"] as? Double,
              let currencyCode = data["currencyCode"] as? String,
              let occurredAt = (data["occurredAt"] as? Timestamp)?.dateValue(),
              let typeRaw = data["type"] as? String,
              let type = BillingHistoryType(rawValue: typeRaw) else {
            return nil
        }

        return BillingHistoryItem(
            id: document.documentID,
            title: title,
            amount: amount,
            currencyCode: currencyCode,
            occurredAt: occurredAt,
            type: type
        )
    }
}
