//
//  ReceiptHistoryItem.swift
//  Ratio
//
//  Created by Codex on 30/01/26.
//

import Foundation

struct ReceiptHistoryItem: Identifiable, Equatable, Hashable {
    let id: String
    let url: String
    let submittedAt: Date
}
