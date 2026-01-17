//
//  CategorySpendItem.swift
//  Ratio
//
//  Created by Codex on 09/01/26.
//

import SwiftUI

struct CategorySpendItem: Identifiable {
    let id = UUID()
    let label: String
    let amount: Double
    let currencyCode: String
    let color: Color
}
