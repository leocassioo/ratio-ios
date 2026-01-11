//
//  HomeCategoryDonutView.swift
//  Ratio
//
//  Created by Codex on 09/01/26.
//

import Charts
import SwiftUI

struct HomeCategoryDonutView: View {
    let items: [CategorySpendItem]

    var body: some View {
        Chart(items) { item in
            SectorMark(
                angle: .value("Valor", item.amount),
                innerRadius: .ratio(0.6),
                angularInset: 2
            )
            .foregroundStyle(item.color)
        }
        .chartLegend(.hidden)
    }
}
