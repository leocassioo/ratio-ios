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
    @Published private(set) var linkedSubscriptionIds: Set<String> = []
    @Published private(set) var hasLoadedGroups = false
    @Published private(set) var usdRate: ExchangeRate?
    @Published private(set) var eurRate: ExchangeRate?

    private let store: SubscriptionsStore
    private let groupsStore: GroupsStore
    private let exchangeRateStore: ExchangeRateStore
    private let analytics: AnalyticsService
    private var listener: ListenerRegistration?
    private var groupsListener: ListenerRegistration?
    private var exchangeRateListener: ListenerRegistration?
    private var eurRateListener: ListenerRegistration?

    init(
        store: SubscriptionsStore? = nil,
        groupsStore: GroupsStore? = nil,
        exchangeRateStore: ExchangeRateStore? = nil,
        analytics: AnalyticsService = .shared
    ) {
        self.store = store ?? SubscriptionsStore()
        self.groupsStore = groupsStore ?? GroupsStore()
        self.exchangeRateStore = exchangeRateStore ?? ExchangeRateStore()
        self.analytics = analytics
    }

    deinit {
        listener?.remove()
        groupsListener?.remove()
        exchangeRateListener?.remove()
        eurRateListener?.remove()
    }

    func startListening(userId: String) {
        listener?.remove()
        groupsListener?.remove()
        exchangeRateListener?.remove()
        eurRateListener?.remove()
        isLoading = true
        errorMessage = nil

        Task {
            try? await store.normalizeNextBillingDates(userId: userId)
        }
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

        groupsListener = groupsStore.listenGroups(for: userId) { [weak self] result in
            DispatchQueue.main.async {
                self?.hasLoadedGroups = true
                switch result {
                case .success(let groups):
                    let linked = groups.compactMap { group -> String? in
                        guard group.ownerId == userId else { return nil }
                        return group.subscriptionId
                    }
                    self?.linkedSubscriptionIds = Set(linked)
                case .failure:
                    self?.linkedSubscriptionIds = []
                }
            }
        }

        exchangeRateListener = exchangeRateStore.listenUsdRate { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let rate):
                    self?.usdRate = rate
                case .failure:
                    self?.usdRate = nil
                }
            }
        }

        eurRateListener = exchangeRateStore.listenEurRate { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let rate):
                    self?.eurRate = rate
                case .failure:
                    self?.eurRate = nil
                }
            }
        }
    }

    func stopListening() {
        listener?.remove()
        groupsListener?.remove()
        exchangeRateListener?.remove()
        eurRateListener?.remove()
        listener = nil
        groupsListener = nil
        exchangeRateListener = nil
        eurRateListener = nil
        subscriptions = []
        linkedSubscriptionIds = []
        hasLoadedGroups = false
        usdRate = nil
        eurRate = nil
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
            analytics.track(.subscription_create, parameters: [
                "category": category.rawValue,
                "period": period.rawValue,
                "currency": currencyCode,
                "source": "manual",
                "result": "success"
            ])
        } catch {
            errorMessage = error.localizedDescription
            analytics.track(.subscription_create, parameters: [
                "category": category.rawValue,
                "period": period.rawValue,
                "currency": currencyCode,
                "source": "manual",
                "result": "error"
            ])
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
        analytics.track(.subscription_edit, parameters: [
            "subscription_id": id,
            "category": category.rawValue,
            "period": period.rawValue,
            "currency": currencyCode
        ])
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
            analytics.track(.subscription_delete, parameters: ["subscription_id": id, "result": "success"])
        } catch {
            errorMessage = error.localizedDescription
            analytics.track(.subscription_delete, parameters: ["subscription_id": id, "result": "error"])
        }
    }

    func estimatedAmount(for subscription: SubscriptionItem, preferredCurrencyCode: String) -> Double? {
        convert(amount: subscription.amount, from: subscription.currencyCode, to: preferredCurrencyCode)
    }

    private func convert(amount: Double, from: String, to: String) -> Double? {
        if from == to {
            return nil
        }
        let usdRate = usdRate
        let eurRate = eurRate

        func toBRL(_ amount: Double, currency: String) -> Double? {
            switch currency {
            case "USD":
                guard let rate = usdRate, rate.rate > 0 else { return nil }
                let base = amount * rate.rate
                let margin = base * max(rate.marginPct, 0)
                return base + margin
            case "EUR":
                guard let rate = eurRate, rate.rate > 0 else { return nil }
                let base = amount * rate.rate
                let margin = base * max(rate.marginPct, 0)
                return base + margin
            case "BRL":
                return amount
            default:
                return nil
            }
        }

        func fromBRL(_ amount: Double, currency: String) -> Double? {
            switch currency {
            case "USD":
                guard let rate = usdRate, rate.rate > 0 else { return nil }
                return amount / rate.rate
            case "EUR":
                guard let rate = eurRate, rate.rate > 0 else { return nil }
                return amount / rate.rate
            case "BRL":
                return amount
            default:
                return nil
            }
        }

        if from == "BRL" {
            return fromBRL(amount, currency: to)
        }
        if to == "BRL" {
            return toBRL(amount, currency: from)
        }
        guard let brlAmount = toBRL(amount, currency: from) else { return nil }
        return fromBRL(brlAmount, currency: to)
    }
}
