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
    let logoURL: String?
    let status: SubscriptionStatus

    init(
        id: String,
        name: String,
        amount: Double,
        currencyCode: String,
        category: SubscriptionCategory,
        period: SubscriptionPeriod,
        nextBillingDate: Date,
        notes: String,
        logoURL: String?,
        status: SubscriptionStatus = .active
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.currencyCode = currencyCode
        self.category = category
        self.period = period
        self.nextBillingDate = nextBillingDate
        self.notes = notes
        self.logoURL = logoURL
        self.status = status
    }
}
