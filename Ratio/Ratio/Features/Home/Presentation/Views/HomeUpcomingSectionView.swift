//
//  HomeUpcomingSectionView.swift
//  Ratio
//
//  Created by Codex on 09/01/26.
//

import SwiftUI

struct HomeUpcomingSectionView: View {
    @EnvironmentObject private var router: AppRouter
    let items: [UpcomingPaymentItem]
    let destinationTab: MainTab
    let estimated: (UpcomingPaymentItem) -> (Double, String)?
    let onTap: (UpcomingPaymentItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                Text("Próximos pagamentos")
                    .font(.headline)
                Spacer()
                Button {
                    router.route(to: destinationTab)
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
                        let estimate = estimated(item)
                        Button {
                            onTap(item)
                        } label: {
                            HomeUpcomingRowView(
                                item: item,
                                estimatedAmount: estimate?.0,
                                estimatedCurrencyCode: estimate?.1
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
