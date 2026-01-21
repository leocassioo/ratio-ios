//
//  RedeemInviteView.swift
//  Ratio
//
//  Created by Codex on 17/01/26.
//

import SwiftUI

struct RedeemInviteView: View {
    @State private var tokenInput = ""
    @State private var resolvedToken = ""
    @State private var shouldNavigate = false

    var body: some View {
        Form {
            Section {
                TextField("Cole o código ou link do convite", text: $tokenInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            } header: {
                Text("Resgatar convite")
            } footer: {
                Text("Você pode colar o link completo ou apenas o código.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Continuar") {
                    let token = normalizeToken(tokenInput)
                    resolvedToken = token
                    shouldNavigate = !token.isEmpty
                }
                .disabled(normalizeToken(tokenInput).isEmpty)
            }
        }
        .navigationTitle("Resgatar convite")
        .navigationBarTitleDisplayMode(.inline)
        .background(navigationLink)
    }

    private var navigationLink: some View {
        NavigationLink(isActive: $shouldNavigate) {
            InviteAcceptanceView(token: resolvedToken)
        } label: {
            EmptyView()
        }
        .hidden()
    }

    private func normalizeToken(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if let tokenParam = trimmed.split(separator: "token=").last {
            return tokenParam.split(separator: "&").first.map(String.init) ?? ""
        }
        return trimmed
    }
}

#Preview {
    NavigationStack {
        RedeemInviteView()
    }
}
