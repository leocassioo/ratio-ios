//
//  GroupsViewModel.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import Combine
import FirebaseFirestore
import Foundation

@MainActor
final class GroupsViewModel: ObservableObject {
    @Published private(set) var groups: [Group] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let store: GroupsStore
    private var listener: ListenerRegistration?

    init(store: GroupsStore? = nil) {
        self.store = store ?? GroupsStore()
    }

    deinit {
        listener?.remove()
    }

    func startListening(userId: String) {
        listener?.remove()
        isLoading = true
        errorMessage = nil

        listener = store.listenGroups(for: userId) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let groups):
                    self?.groups = groups
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        groups = []
    }

    func createGroup(
        name: String,
        subscription: SubscriptionItem,
        billingDay: Int?,
        notes: String?,
        members: [GroupMemberDraft],
        ownerId: String
    ) async {
        let memberIds = members.compactMap { $0.userId }.unique() + [ownerId]
        let membersPreview: [[String: Any]] = members.map { member in
            [
                "id": member.id,
                "name": member.name,
                "amount": member.amountValue,
                "status": member.status.rawValue,
                "userId": member.userId as Any
            ]
        }

        let data: [String: Any] = [
            "name": name,
            "category": subscription.category.rawValue,
            "totalAmount": subscription.amount,
            "currencyCode": subscription.currencyCode,
            "billingPeriod": subscription.period.label,
            "billingDay": billingDay as Any,
            "notes": notes as Any,
            "ownerId": ownerId,
            "memberIds": Array(Set(memberIds)),
            "membersPreview": membersPreview,
            "subscriptionId": subscription.id,
            "subscriptionName": subscription.name,
            "subscriptionCategory": subscription.category.rawValue,
            "subscriptionPeriod": subscription.period.rawValue,
            "subscriptionNextBillingDate": Timestamp(date: subscription.nextBillingDate),
            "createdAt": FieldValue.serverTimestamp()
        ]

        do {
            try await store.createGroup(data: data, members: members, ownerId: ownerId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
