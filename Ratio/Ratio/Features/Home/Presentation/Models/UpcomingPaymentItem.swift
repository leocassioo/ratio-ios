//
//  UpcomingPaymentItem.swift
//  Ratio
//
//  Created by Codex on 09/01/26.
//

import Foundation

struct UpcomingPaymentItem: Identifiable {
    let id = UUID()
    let subscriptionId: String?
    let groupId: String?
    let name: String
    let initials: String
    let category: SubscriptionCategory?
    let amount: Double
    let currencyCode: String
    let dueDate: Date
    let period: String
    let logoURL: String?
}
