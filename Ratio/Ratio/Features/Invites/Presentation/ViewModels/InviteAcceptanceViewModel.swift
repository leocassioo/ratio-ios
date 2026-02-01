//
//  InviteAcceptanceViewModel.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import Combine
import Foundation

@MainActor
final class InviteAcceptanceViewModel: ObservableObject {
    @Published private(set) var inviteInfo: InviteInfo?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var didAccept = false

    private let token: String
    private let store: InvitesStore
    private let usersStore: UsersStore
    private let analytics: AnalyticsService

    init(
        token: String,
        store: InvitesStore? = nil,
        usersStore: UsersStore? = nil,
        analytics: AnalyticsService = .shared
    ) {
        self.token = token
        self.store = store ?? InvitesStore()
        self.usersStore = usersStore ?? UsersStore()
        self.analytics = analytics
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            inviteInfo = try await store.fetchInvite(token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func accept(userId: String, fallbackName: String?) async {
        isLoading = true
        errorMessage = nil
        do {
            let storedName = try await usersStore.fetchUserName(userId: userId)
            let resolvedName = [storedName, fallbackName]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { !$0.isEmpty }) ?? "Membro"
            try await store.acceptInvite(token: token, userId: userId, userName: resolvedName)
            didAccept = true
            if let groupId = inviteInfo?.groupId {
                analytics.track(.invite_accept_success, parameters: ["group_id": groupId])
            } else {
                analytics.track(.invite_accept_success, parameters: [:])
            }
        } catch {
            errorMessage = error.localizedDescription
            let reason = Self.errorReason(from: error)
            analytics.track(.invite_accept_error, parameters: ["reason": reason])
        }
        isLoading = false
    }

    private static func errorReason(from error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain):\(nsError.code)"
    }
}
