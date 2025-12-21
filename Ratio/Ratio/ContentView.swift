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
            if user != nil {
                VStack {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                    Text("Logged In!")
                    
                    Button("Logout") {
                        try? AuthService.shared.logout()
                    }
                }
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
