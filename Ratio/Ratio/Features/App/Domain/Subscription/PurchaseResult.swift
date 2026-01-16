//
//  PurchaseResult.swift
//  Ratio
//
//  Created by Codex on 23/12/25.
//

import Foundation

enum PurchaseResult {
    case success
    case cancelled
    case pending
    case failed(Error)
}
