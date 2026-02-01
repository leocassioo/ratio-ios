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
    private let analytics = AnalyticsService.shared

    var body: some View {
        Group {
            if !authViewModel.isAuthReady {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if authViewModel.user != nil {
                MainTabView()
            } else {
                NavigationStack(path: $router.authPath) {
                    LoginView()
                        .navigationDestination(for: AppRoute.self) { route in
                            switch route {
                            case .signup:
                                SignupView()
                            case .passwordReset:
                                PasswordResetView()
                            default:
                                EmptyView()
                            }
                        }
                }
            }
        }
        .environmentObject(authViewModel)
        .environmentObject(router)
        .sheet(item: inviteSheetTokenBinding) { token in
            NavigationStack {
                InviteAcceptanceView(token: token.id, showsCloseButton: true)
                    .environmentObject(authViewModel)
            }
        }
        .onOpenURL { url in
            inviteCoordinator.handleURL(url)
            analytics.track(.deeplink_open, parameters: [
                "source": url.host ?? "unknown",
                "route": url.path
            ])
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

    private var inviteSheetTokenBinding: Binding<InviteToken?> {
        Binding(
            get: {
                guard authViewModel.user != nil else { return nil }
                return inviteCoordinator.pendingToken
            },
            set: { inviteCoordinator.pendingToken = $0 }
        )
    }
}

#Preview {
    ContentView()
}
