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

    var body: some View {
        SwiftUI.Group {
            if authViewModel.user != nil {
                MainTabView()
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
    }
}

#Preview {
    ContentView()
}
