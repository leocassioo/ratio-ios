//
//  SubscriptionLogoView.swift
//  Ratio
//
//  Created by Codex on 31/01/26.
//

import SwiftUI

struct SubscriptionLogoView: View {
    let subscriptionId: String?
    let initials: String
    let backgroundColor: Color
    let foregroundColor: Color
    let size: CGFloat
    let cornerRadius: CGFloat

    @State private var logoImage: Image?

    var body: some View {
        Group {
            if let logoImage {
                logoImage
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                InitialsBadgeView(
                    initials: initials,
                    backgroundColor: backgroundColor,
                    foregroundColor: foregroundColor,
                    size: size,
                    cornerRadius: cornerRadius
                )
            }
        }
        .onAppear(perform: loadLogo)
        .onChange(of: subscriptionId) { _, _ in
            loadLogo()
        }
        .onReceive(NotificationCenter.default.publisher(for: SubscriptionLogoStore.logoUpdatedNotification)) { notification in
            guard let id = notification.userInfo?["id"] as? String else { return }
            if id == subscriptionId {
                loadLogo()
            }
        }
    }

    private func loadLogo() {
        guard let subscriptionId,
              let uiImage = SubscriptionLogoStore.shared.loadLogo(for: subscriptionId) else {
            logoImage = nil
            return
        }
        logoImage = Image(uiImage: uiImage)
    }
}

#Preview {
    SubscriptionLogoView(
        subscriptionId: nil,
        initials: "NF",
        backgroundColor: Color(.systemIndigo).opacity(0.16),
        foregroundColor: Color(.systemIndigo),
        size: 42,
        cornerRadius: 12
    )
    .padding()
}
