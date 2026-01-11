//
//  HomeUpcomingSectionView.swift
//  Ratio
//
//  Created by Codex on 09/01/26.
//

import SwiftUI

struct HomeUpcomingSectionView: View {
    @EnvironmentObject private var navigationState: AppNavigationState
    let items: [UpcomingPaymentItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                Text("Próximos pagamentos")
                    .font(.headline)
                Spacer()
                Button {
                    navigationState.route(to: .subscriptions)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
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
