//
//  BillingHistoryItem.swift
//  Ratio
//
//  Created by Codex on 16/02/26.
//

import Foundation

struct BillingHistoryItem: Identifiable, Equatable {
    let id: String
    let title: String
    let amount: Double
    let currencyCode: String
    let occurredAt: Date
    let type: BillingHistoryType
}
