//
//  UpcomingPaymentItem.swift
//  Ratio
//
//  Created by Codex on 09/01/26.
//

import Foundation

struct UpcomingPaymentItem: Identifiable {
    let id: UUID
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

    init(
        subscriptionId: String?,
        groupId: String?,
        name: String,
        initials: String,
        category: SubscriptionCategory?,
        amount: Double,
        currencyCode: String,
        dueDate: Date,
        period: String,
        logoURL: String? = nil
    ) {
        self.id = UUID()
        self.subscriptionId = subscriptionId
        self.groupId = groupId
        self.name = name
        self.initials = initials
        self.category = category
        self.amount = amount
        self.currencyCode = currencyCode
        self.dueDate = dueDate
        self.period = period
        self.logoURL = logoURL
    }
}
