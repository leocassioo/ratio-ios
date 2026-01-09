//
//  MainTabView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var navigationState: AppNavigationState

    var body: some View {
        TabView(selection: $navigationState.selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(MainTab.home)

            SubscriptionsView()
                .tabItem {
                    Label("Assinaturas", systemImage: "creditcard")
                }
                .tag(MainTab.subscriptions)

            GroupsView()
                .tabItem {
                    Label("Grupos", systemImage: "person.3")
                }
                .tag(MainTab.groups)

            SettingsView()
                .tabItem {
                    Label("Ajustes", systemImage: "gearshape")
                }
                .tag(MainTab.settings)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppNavigationState())
}
