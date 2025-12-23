//
//  GroupsView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI

struct GroupsView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "person.3")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Grupos em breve")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Grupos")
        }
    }
}

#Preview {
    GroupsView()
}
