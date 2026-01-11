//
//  HomeInsightsRowView.swift
//  Ratio
//
//  Created by Codex on 09/01/26.
//

import SwiftUI

struct HomeInsightsRowView: View {
    let insights: [HomeInsightItem]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(insights) { insight in
                    HomeInsightChipView(item: insight)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}
