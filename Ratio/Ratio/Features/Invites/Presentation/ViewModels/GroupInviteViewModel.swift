//
//  GroupInviteViewModel.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import Combine
import Foundation

@MainActor
final class GroupInviteViewModel: ObservableObject {
    @Published private(set) var inviteURL: URL?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let store: InvitesStore
    private let groupId: String
    private let groupName: String
    private let ownerId: String
    private let analytics: AnalyticsService
    private let baseInviteURL = "https://uaipixel.com/invite"

    init(
        groupId: String,
        groupName: String,
        ownerId: String,
        store: InvitesStore? = nil,
        analytics: AnalyticsService = .shared
    ) {
        self.groupId = groupId
        self.groupName = groupName
        self.ownerId = ownerId
        self.store = store ?? InvitesStore()
        self.analytics = analytics
    }

    func createInvite() async {
        isLoading = true
        errorMessage = nil
        inviteURL = nil

        do {
            let expiresAt = Date().addingTimeInterval(60 * 60 * 24)
            let token = try await store.createInvite(
                groupId: groupId,
                groupName: groupName,
                createdBy: ownerId,
                expiresAt: expiresAt,
                maxUses: 0
            )
            inviteURL = URL(string: "\(baseInviteURL)?token=\(token)")
            analytics.track(.invite_create, parameters: [
                "group_id": groupId,
                "max_uses": 0,
                "expires_in_hours": 24
            ])
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
