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
    private let baseInviteURL = "https://uaipixel.com/invite"

    init(groupId: String, groupName: String, ownerId: String, store: InvitesStore? = nil) {
        self.groupId = groupId
        self.groupName = groupName
        self.ownerId = ownerId
        self.store = store ?? InvitesStore()
    }

    func createInvite() async {
        isLoading = true
        errorMessage = nil
        inviteURL = nil

        do {
            let expiresAt = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            let token = try await store.createInvite(
                groupId: groupId,
                groupName: groupName,
                createdBy: ownerId,
                expiresAt: expiresAt,
                maxUses: 1
            )
            inviteURL = URL(string: "\(baseInviteURL)?token=\(token)")
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
