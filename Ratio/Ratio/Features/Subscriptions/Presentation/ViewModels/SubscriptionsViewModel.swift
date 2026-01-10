//
//  SubscriptionsViewModel.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import Combine
import FirebaseFirestore
import Foundation
import Combine

@MainActor
final class SubscriptionsViewModel: ObservableObject {
    @Published private(set) var subscriptions: [SubscriptionItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let store: SubscriptionsStore
    private var listener: ListenerRegistration?

    init(store: SubscriptionsStore? = nil) {
        self.store = store ?? SubscriptionsStore()
    }

    deinit {
        listener?.remove()
    }

    func startListening(userId: String) {
        listener?.remove()
        isLoading = true
        errorMessage = nil

        listener = store.listenSubscriptions(for: userId) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let items):
                    self?.subscriptions = items
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        subscriptions = []
    }

    func createSubscription(
        name: String,
        amount: Double,
        currencyCode: String,
        category: SubscriptionCategory,
        period: SubscriptionPeriod,
        nextBillingDate: Date,
        notes: String?,
        ownerId: String
    ) async {
        let data: [String: Any] = [
            "name": name,
            "amount": amount,
            "currencyCode": currencyCode,
            "category": category.rawValue,
            "period": period.rawValue,
            "nextBillingDate": Timestamp(date: nextBillingDate),
            "notes": notes as Any,
            "ownerId": ownerId,
            "createdAt": FieldValue.serverTimestamp()
        ]

        do {
            try await store.createSubscription(userId: ownerId, data: data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateSubscription(
        id: String,
        name: String,
        amount: Double,
        currencyCode: String,
        category: SubscriptionCategory,
        period: SubscriptionPeriod,
        nextBillingDate: Date,
        notes: String?,
        ownerId: String
    ) async {
        let data: [String: Any] = [
            "name": name,
            "amount": amount,
            "currencyCode": currencyCode,
            "category": category.rawValue,
            "period": period.rawValue,
            "nextBillingDate": Timestamp(date: nextBillingDate),
            "notes": notes as Any,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        do {
            try await store.updateSubscription(userId: ownerId, id: id, data: data)
            let groupData: [String: Any] = [
                "subscriptionName": name,
                "subscriptionCategory": category.rawValue,
                "subscriptionPeriod": period.rawValue,
                "subscriptionNextBillingDate": Timestamp(date: nextBillingDate),
                "totalAmount": amount,
                "currencyCode": currencyCode,
                "billingPeriod": period.label,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            try await store.updateLinkedGroups(subscriptionId: id, ownerId: ownerId, data: groupData)
            try await store.updateLinkedGroupAmounts(subscriptionId: id, ownerId: ownerId, totalAmount: amount)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSubscription(id: String, ownerId: String) async {
        do {
            try await store.deleteSubscription(userId: ownerId, id: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
