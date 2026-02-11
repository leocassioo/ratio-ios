//
//  SubscriptionLogoView.swift
//  Ratio
//
//  Created by Codex on 31/01/26.
//

import FirebaseAuth
import SwiftUI

struct SubscriptionLogoView: View {
    let subscriptionId: String?
    let logoURL: URL?
    let initials: String
    let backgroundColor: Color
    let foregroundColor: Color
    let size: CGFloat
    let cornerRadius: CGFloat

    @State private var logoImage: Image?
    @State private var hasAttemptedRemoteFetch = false

    var body: some View {
        Group {
            if let logoImage {
                logoImage
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else if let logoURL {
                AsyncImage(url: logoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        InitialsBadgeView(
                            initials: initials,
                            backgroundColor: backgroundColor,
                            foregroundColor: foregroundColor,
                            size: size,
                            cornerRadius: cornerRadius
                        )
                    }
                }
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
        .onChange(of: logoURL?.absoluteString) { _, _ in
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
        hasAttemptedRemoteFetch = false
        guard let subscriptionId,
              let uiImage = SubscriptionLogoStore.shared.loadLogo(for: subscriptionId) else {
            if let logoURL, let cached = RemoteImageStore.shared.loadImage(for: logoURL) {
                logoImage = Image(uiImage: cached)
                return
            }
            logoImage = nil
            if let logoURL {
                fetchRemoteFromURL(logoURL)
            } else {
                fetchRemoteIfNeeded()
            }
            return
        }
        logoImage = Image(uiImage: uiImage)
    }

    private func fetchRemoteFromURL(_ url: URL) {
        Task {
            if let image = await RemoteImageStore.shared.fetchImage(for: url) {
                await MainActor.run {
                    logoImage = Image(uiImage: image)
                }
            }
        }
    }

    private func fetchRemoteIfNeeded() {
        guard !hasAttemptedRemoteFetch,
              let subscriptionId,
              let userId = Auth.auth().currentUser?.uid else {
            return
        }
        hasAttemptedRemoteFetch = true
        Task {
            if let image = await SubscriptionLogoStore.shared.fetchRemoteLogo(for: subscriptionId, userId: userId) {
                await MainActor.run {
                    logoImage = Image(uiImage: image)
                }
            }
        }
    }
}

#Preview {
    SubscriptionLogoView(
        subscriptionId: nil,
        logoURL: nil,
        initials: "NF",
        backgroundColor: Color(.systemIndigo).opacity(0.16),
        foregroundColor: Color(.systemIndigo),
        size: 42,
        cornerRadius: 12
    )
    .padding()
}
