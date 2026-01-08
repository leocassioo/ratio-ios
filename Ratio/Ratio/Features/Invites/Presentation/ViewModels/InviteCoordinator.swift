//
//  InviteCoordinator.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import Combine
import Foundation

final class InviteCoordinator: ObservableObject {
    @Published var pendingToken: InviteToken?

    func handleURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
              !token.isEmpty else {
            return
        }

        pendingToken = InviteToken(token)
    }
}
