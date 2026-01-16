//
//  ContentView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var inviteCoordinator = InviteCoordinator()
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        Group {
            if authViewModel.user != nil {
                MainTabView()
            } else {
                NavigationStack {
                    LoginView()
                }
            }
        }
        .environmentObject(authViewModel)
        .environmentObject(router)
        .sheet(item: $inviteCoordinator.pendingToken) { token in
            InviteAcceptanceView(token: token.id)
                .environmentObject(authViewModel)
        }
        .onOpenURL { url in
            inviteCoordinator.handleURL(url)
        }
        .onAppear {
            if let payload = NotificationRouteHandler.shared.consumePendingPayload() {
                switch payload.route {
                case .home:
                    router.route(to: .home)
                case .subscriptions:
                    router.route(to: .subscriptions)
                case .groups:
                    router.route(to: .groups, groupId: payload.groupId)
                case .settings:
                    router.route(to: .settings)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .notificationRouteDidReceive)) { notification in
            guard let payload = notification.object as? NotificationRoutePayload else { return }
            switch payload.route {
            case .home:
                router.route(to: .home)
            case .subscriptions:
                router.route(to: .subscriptions)
            case .groups:
                router.route(to: .groups, groupId: payload.groupId)
            case .settings:
                router.route(to: .settings)
            }
        }
    }
}

#Preview {
    ContentView()
}
