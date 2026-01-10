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
    @StateObject private var navigationState = AppNavigationState()

    var body: some View {
        SwiftUI.Group {
            if authViewModel.user != nil {
                MainTabView()
                    .environmentObject(navigationState)
            } else {
                LoginView()
            }
        }
        .environmentObject(authViewModel)
        .sheet(item: $inviteCoordinator.pendingToken) { token in
            InviteAcceptanceView(token: token.id)
                .environmentObject(authViewModel)
        }
        .onOpenURL { url in
            inviteCoordinator.handleURL(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .notificationRouteDidReceive)) { notification in
            guard let payload = notification.object as? NotificationRoutePayload else { return }
            switch payload.route {
            case .home:
                navigationState.route(to: .home)
            case .subscriptions:
                navigationState.route(to: .subscriptions)
            case .groups:
                navigationState.route(to: .groups, groupId: payload.groupId)
            case .settings:
                navigationState.route(to: .settings)
            }
        }
    }
}

#Preview {
    ContentView()
}
