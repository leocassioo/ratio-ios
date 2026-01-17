//
//  MonthlySpendItem.swift
//  Ratio
//
//  Created by Codex on 20/02/26.
//

import Foundation

struct MonthlySpendItem: Identifiable, Equatable {
    let id = UUID()
    let monthStart: Date
    let label: String
    let amount: Double
    let currencyCode: String
}
