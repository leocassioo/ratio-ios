//
//  HomeInsightsRowView.swift
//  Ratio
//
//  Created by Codex on 09/01/26.
//

import SwiftUI

struct HomeInsightsRowView: View {
    let insights: [HomeInsightItem]
    let onTap: (HomeInsightItem) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(insights) { insight in
                    Button {
                        onTap(insight)
                    } label: {
                        HomeInsightChipView(item: insight)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}
