//
//  HomeUpcomingSectionView.swift
//  Ratio
//
//  Created by Codex on 09/01/26.
//

import SwiftUI

struct HomeUpcomingSectionView: View {
    let items: [UpcomingPaymentItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                Text("Próximos pagamentos")
                    .font(.headline)
            }

            if items.isEmpty {
                Text("Nenhum pagamento próximo")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(items) { item in
                        HomeUpcomingRowView(item: item)
                    }
                }
            }
        }
    }
}
