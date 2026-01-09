//
//  Group.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import Foundation

struct Group: Identifiable, Equatable {
    let id: String
    let name: String
    let category: GroupCategory
    let totalAmount: Double
    let currencyCode: String
    let billingPeriod: String
    let billingDay: Int?
    let notes: String?
    let ownerId: String?
    let subscriptionId: String?
    let subscriptionName: String?
    let subscriptionCategory: String?
    let subscriptionPeriod: String?
    let subscriptionNextBillingDate: Date?
    let chargeDay: Int?
    let chargeNextBillingDate: Date?
    let members: [GroupMember]
}
