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

        // Fast path: explicit token query anywhere
        if let tokenParam = trimmed.split(separator: "token=").last {
            let candidate = tokenParam.split(separator: "&").first.map(String.init) ?? ""
            return candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try parsing URL (including fragment)
        if let url = URL(string: trimmed) {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                if let token = components.queryItems?.first(where: { $0.name.lowercased() == "token" })?.value {
                    return token
                }

                if let fragment = components.fragment, !fragment.isEmpty {
                    if let tokenParam = fragment.split(separator: "token=").last {
                        let candidate = tokenParam.split(separator: "&").first.map(String.init) ?? ""
                        if !candidate.isEmpty { return candidate }
                    }
                    if let token = tokenFromInvitePath(fragment) {
                        return token
                    }
                }
            }

            if let token = tokenFromInvitePath(url.path) {
                return token
            }
        }

        // Support links without scheme
        if let url = URL(string: "https://\(trimmed)") {
            if let token = tokenFromInvitePath(url.path) {
                return token
            }
        }

        // Fallback: assume the input itself is the token
        return trimmed
    }

    private func tokenFromInvitePath(_ path: String) -> String? {
        guard let range = path.range(of: "invite/") else { return nil }
        let tokenPart = path[range.upperBound...]
        let token = tokenPart.split(separator: "/").first.map(String.init) ?? ""
        return token.isEmpty ? nil : token
    }
}

#Preview {
    NavigationStack {
        RedeemInviteView()
    }
}
