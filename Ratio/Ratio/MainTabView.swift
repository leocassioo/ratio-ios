//
//  MainTabView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            GroupsView()
                .tabItem {
                    Label("Grupos", systemImage: "person.3")
                }

            SettingsView()
                .tabItem {
                    Label("Ajustes", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    MainTabView()
}
