//
//  ExchangeRate.swift
//  Ratio
//
//  Created by Codex on 20/02/26.
//

import Foundation

struct ExchangeRate: Equatable {
    let rate: Double
    let marginPct: Double
    let asOf: Date
    let source: String
}
