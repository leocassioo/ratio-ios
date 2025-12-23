//
//  HomeView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "creditcard")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Dashboard em breve")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Assinaturas")
        }
    }
}

#Preview {
    HomeView()
}
