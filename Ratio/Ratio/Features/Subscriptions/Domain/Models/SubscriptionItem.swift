//
//  SubscriptionItem.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import Foundation

struct SubscriptionItem: Identifiable, Equatable {
    let id: String
    let name: String
    let amount: Double
    let currencyCode: String
    let category: SubscriptionCategory
    let period: SubscriptionPeriod
    let nextBillingDate: Date
    let notes: String
}
