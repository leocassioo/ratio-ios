//
//  ContentView.swift
//  Ratio
//
//  Created by Leonardo Figueiredo on 21/12/25.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @State private var user: User? = nil
    
    var body: some View {
        Group {
            if let user = user { // unwrapped
                MainTabView(userId: user.uid)
            } else {
                LoginView()
            }
        }
        .onAppear {
            Auth.auth().addStateDidChangeListener { auth, user in
                self.user = user
            }
        }
    }
}

#Preview {
    ContentView()
}
