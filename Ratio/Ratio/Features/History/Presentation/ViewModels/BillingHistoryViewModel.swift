//
//  BillingHistoryViewModel.swift
//  Ratio
//
//  Created by Codex on 16/02/26.
//

import FirebaseFirestore
import Foundation
import Combine

@MainActor
final class BillingHistoryViewModel: ObservableObject {
    @Published private(set) var items: [BillingHistoryItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var annualEstimateAmount: Double = 0
    @Published private(set) var annualEstimateCurrency: String = "BRL"

    private let store: BillingHistoryStore
    private let subscriptionsStore: SubscriptionsStore
    private let groupsStore: GroupsStore
    private var listener: ListenerRegistration?

    init(
        store: BillingHistoryStore = BillingHistoryStore(),
        subscriptionsStore: SubscriptionsStore = SubscriptionsStore(),
        groupsStore: GroupsStore = GroupsStore()
    ) {
        self.store = store
        self.subscriptionsStore = subscriptionsStore
        self.groupsStore = groupsStore
    }

    deinit {
        listener?.remove()
    }

    func startListening(userId: String) {
        listener?.remove()
        isLoading = true
        errorMessage = nil

        listener = store.listenHistory(for: userId) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let items):
                    self?.items = items
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        items = []
    }

    func loadAnnualEstimate(userId: String) {
        Task {
            let subscriptions = (try? await subscriptionsStore.fetchSubscriptions(userId: userId)) ?? []
            let groups = (try? await groupsStore.fetchGroups(userId: userId)) ?? []

            let subscriptionContributions = subscriptions.map { item in
                (currency: item.currencyCode, monthly: monthlyEquivalent(amount: item.amount, period: item.period))
            }

            let groupContributions: [(String, Double)] = groups.compactMap { group in
                guard group.ownerId != userId,
                      let member = group.members.first(where: { $0.userId == userId }) else {
                    return nil
                }
                let period = periodFromGroup(group)
                return (group.currencyCode, monthlyEquivalent(amount: member.amount, period: period))
            }

            let allContributions = subscriptionContributions + groupContributions
            guard let firstCurrency = allContributions.first?.currency, !firstCurrency.isEmpty else {
                await MainActor.run {
                    self.annualEstimateAmount = 0
                    self.annualEstimateCurrency = "BRL"
                }
                return
            }

            let totalsByCurrency = Dictionary(grouping: allContributions, by: { $0.currency })
                .mapValues { items in
                    items.reduce(0) { partial, item in
                        partial + item.monthly
                    }
                }

            let monthlyTotal = totalsByCurrency[firstCurrency] ?? 0
            await MainActor.run {
                self.annualEstimateCurrency = firstCurrency
                self.annualEstimateAmount = monthlyTotal * 12
            }
        }
    }

    private func monthlyEquivalent(amount: Double, period: SubscriptionPeriod?) -> Double {
        guard let period else { return amount }
        switch period {
        case .weekly:
            return amount * 4.33
        case .monthly:
            return amount
        case .quarterly:
            return amount / 3
        case .yearly:
            return amount / 12
        case .oneTime:
            return amount
        }
    }

    private func periodFromGroup(_ group: SharedGroup) -> SubscriptionPeriod? {
        if let raw = group.subscriptionPeriod,
           let period = SubscriptionPeriod(rawValue: raw) {
            return period
        }
        let label = group.billingPeriod.lowercased()
        if label.contains("semana") {
            return .weekly
        }
        if label.contains("trimestre") {
            return .quarterly
        }
        if label.contains("anual") || label.contains("ano") {
            return .yearly
        }
        if label.contains("mensal") || label.contains("mês") {
            return .monthly
        }
        if label.contains("única") || label.contains("unica") {
            return .oneTime
        }
        return nil
    }
}
