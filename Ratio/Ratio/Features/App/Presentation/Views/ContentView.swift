//
//  ContentView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        SwiftUI.Group {
            if authViewModel.user != nil {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .environmentObject(authViewModel)
    }
}

#Preview {
    ContentView()
}
