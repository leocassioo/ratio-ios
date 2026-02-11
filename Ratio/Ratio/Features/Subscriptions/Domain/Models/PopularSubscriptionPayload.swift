//
//  PopularSubscriptionPayload.swift
//  Ratio
//
//  Created by Codex on 31/01/26.
//

import Foundation

struct PopularSubscriptionPayload: Decodable {
    let items: [PopularSubscriptionPayloadItem]
}

struct PopularSubscriptionPayloadItem: Decodable {
    let name: String
    let category: String
    let period: String
    let currencyCode: String
    let suggestedAmount: Double?
    let imageUrl: String?
}
