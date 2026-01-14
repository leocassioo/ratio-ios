//
//  HomeViewModel.swift
//  Ratio
//
//  Created by Codex on 09/01/26.
//

import FirebaseFirestore
import Foundation
import Combine
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var totalMonthlyAmount: Double = 0
    @Published private(set) var currencyCode: String = "BRL"
    @Published private(set) var hasMixedCurrencies = false
    @Published private(set) var totalsByCurrency: [String: Double] = [:]
    @Published private(set) var insights: [HomeInsightItem] = []
    @Published private(set) var upcomingPayments: [UpcomingPaymentItem] = []
    @Published private(set) var categorySpends: [CategorySpendItem] = []
    @Published private(set) var hasSubscriptions = false
    @Published private(set) var hasGroups = false

    private let subscriptionsStore: SubscriptionsStore
    private let groupsStore: GroupsStore
    private var listener: ListenerRegistration?
    private var groupsListener: ListenerRegistration?
    private var subscriptions: [SubscriptionItem] = []
    private var groups: [SharedGroup] = []
    private var userId: String?
    private var didLoadInitial = false

    init(store: SubscriptionsStore? = nil, groupsStore: GroupsStore? = nil) {
        self.subscriptionsStore = store ?? SubscriptionsStore()
        self.groupsStore = groupsStore ?? GroupsStore()
    }

    deinit {
        listener?.remove()
        groupsListener?.remove()
    }

    func startListening(userId: String) {
        if self.userId != userId {
            didLoadInitial = false
        }
        self.userId = userId
        listener?.remove()
        groupsListener?.remove()
        Task {
            try? await subscriptionsStore.normalizeNextBillingDates(userId: userId)
            try? await groupsStore.normalizeChargeDates(for: userId)

            if !didLoadInitial {
                if let subscriptions = try? await subscriptionsStore.fetchSubscriptions(userId: userId) {
                    await MainActor.run {
                        self.subscriptions = subscriptions
                        self.hasSubscriptions = !subscriptions.isEmpty
                        self.updateTotals()
                        self.updateInsights()
                        self.updateUpcomingPayments()
                        self.updateCategorySpends()
                    }
                }

                if let groups = try? await groupsStore.fetchGroups(userId: userId) {
                    await MainActor.run {
                        self.groups = groups
                        self.hasGroups = !groups.isEmpty
                        self.updateTotals()
                        self.updateInsights()
                        self.updateUpcomingPayments()
                        self.updateCategorySpends()
                    }
                }

                await MainActor.run {
                    self.didLoadInitial = true
                }
            }
        }
        listener = subscriptionsStore.listenSubscriptions(for: userId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let items):
                    self?.subscriptions = items
                    self?.hasSubscriptions = !items.isEmpty
                    self?.updateTotals()
                    self?.updateInsights()
                    self?.updateUpcomingPayments()
                    self?.updateCategorySpends()
                case .failure:
                    self?.totalMonthlyAmount = 0
                    self?.hasSubscriptions = false
                }
            }
        }

        groupsListener = groupsStore.listenGroups(for: userId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let groups):
                    self?.groups = groups
                    self?.hasGroups = !groups.isEmpty
                    self?.updateInsights()
                    self?.updateUpcomingPayments()
                    self?.updateCategorySpends()
                    self?.updateTotals()
                case .failure:
                    self?.groups = []
                    self?.hasGroups = false
                }
            }
        }
    }

    func stopListening() {
        listener?.remove()
        groupsListener?.remove()
        listener = nil
        groupsListener = nil
        totalMonthlyAmount = 0
        insights = []
        upcomingPayments = []
        categorySpends = []
        hasSubscriptions = false
        hasGroups = false
    }

    private func updateTotals() {
        let contributions = buildContributions()
        guard let firstCurrency = contributions.first?.currencyCode, !firstCurrency.isEmpty else {
            totalMonthlyAmount = 0
            currencyCode = "BRL"
            hasMixedCurrencies = false
            totalsByCurrency = [:]
            return
        }

        totalsByCurrency = Dictionary(grouping: contributions, by: { $0.currencyCode })
            .mapValues { currencyItems in
                currencyItems.reduce(0) { partial, item in
                    partial + item.monthlyAmount
                }
            }
        currencyCode = firstCurrency
        hasMixedCurrencies = totalsByCurrency.keys.contains { $0 != firstCurrency }
        totalMonthlyAmount = totalsByCurrency[firstCurrency] ?? 0
    }

    private func monthlyEquivalent(for item: SubscriptionItem) -> Double {
        monthlyEquivalent(for: item.amount, period: item.period)
    }

    private func monthlyEquivalent(for amount: Double, period: SubscriptionPeriod?) -> Double {
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
        }
    }

    private func updateInsights() {
        guard let userId else {
            insights = []
            return
        }

        let ownedGroups = groups.filter { $0.ownerId == userId }
        let linkedSubscriptionIds = Set(ownedGroups.compactMap { $0.subscriptionId })
        let subscriptionsWithoutGroup = subscriptions.filter { !linkedSubscriptionIds.contains($0.id) }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dueTodaySubscriptions = subscriptions.filter {
            let effective = nextDateForDisplay($0.nextBillingDate, period: $0.period)
            return calendar.isDate(effective, inSameDayAs: today)
        }

        let dueTodayGroups = groups.filter { group in
            let date = group.chargeNextBillingDate ?? group.subscriptionNextBillingDate
            guard let date else { return false }
            let effective = nextDateForDisplay(date, period: periodFromGroup(group))
            return calendar.isDate(effective, inSameDayAs: today)
        }

        let pendingApprovals = ownedGroups.reduce(0) { partial, group in
            partial + group.members.filter { $0.status == .submitted }.count
        }

        let savings = groups.reduce(0.0) { partial, group in
            guard group.currencyCode == currencyCode else { return partial }
            guard let member = group.members.first(where: { $0.userId == userId }) else { return partial }
            return partial + max(0, group.totalAmount - member.amount)
        }

        var items: [HomeInsightItem] = []
        if !subscriptionsWithoutGroup.isEmpty {
            items.append(HomeInsightItem(
                title: "\(subscriptionsWithoutGroup.count) assinaturas sem grupo",
                icon: "person.3"
            ))
        }

        let dueTodayTotal = dueTodaySubscriptions.count + dueTodayGroups.count
        if dueTodayTotal > 0 {
            items.append(HomeInsightItem(
                title: "\(dueTodayTotal) cobranças hoje",
                icon: "bell.badge"
            ))
        }

        if pendingApprovals > 0 {
            items.append(HomeInsightItem(
                title: "\(pendingApprovals) pagamentos para aprovar",
                icon: "checkmark.seal"
            ))
        }

        if savings > 0 {
            items.append(HomeInsightItem(
                title: "\(formattedCurrency(savings)) economizados",
                icon: "leaf"
            ))
        }

        insights = items
    }

    private func updateUpcomingPayments() {
        guard let userId else {
            upcomingPayments = []
            return
        }

        let subscriptionItems: [UpcomingPaymentItem] = subscriptions.map { item in
            let effectiveDate = nextDateForDisplay(item.nextBillingDate, period: item.period)
            return UpcomingPaymentItem(
                name: item.name,
                initials: initials(for: item.name),
                amount: item.amount,
                currencyCode: item.currencyCode,
                dueDate: effectiveDate,
                period: item.period.label
            )
        }

        let groupItems = groups.compactMap { group -> UpcomingPaymentItem? in
            if group.ownerId == userId {
                return nil
            }
            let dueDate = group.chargeNextBillingDate ?? group.subscriptionNextBillingDate
            guard let dueDate else { return nil }
            guard let member = group.members.first(where: { $0.userId == userId }) else { return nil }
            let effectiveDate = nextDateForDisplay(dueDate, period: periodFromGroup(group))
            return UpcomingPaymentItem(
                name: group.name,
                initials: initials(for: group.name),
                amount: member.amount,
                currencyCode: group.currencyCode,
                dueDate: effectiveDate,
                period: group.billingPeriod
            )
        }

        upcomingPayments = (subscriptionItems + groupItems)
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(4)
            .map { $0 }
    }

    private func updateCategorySpends() {
        guard let userId else {
            categorySpends = []
            return
        }

        let subscriptionTotals = Dictionary(grouping: subscriptions, by: { $0.category.label })
            .mapValues { items in
                items.reduce(0) { partial, item in
                    partial + monthlyEquivalent(for: item)
                }
            }

        let groupTotals = groups.reduce(into: [String: Double]()) { partial, group in
            guard group.ownerId != userId,
                  let member = group.members.first(where: { $0.userId == userId }) else {
                return
            }
            let period = periodFromGroup(group)
            partial[group.category.label, default: 0] += monthlyEquivalent(for: member.amount, period: period)
        }

        let mergedTotals = subscriptionTotals.merging(groupTotals, uniquingKeysWith: +)
        if mergedTotals.isEmpty {
            categorySpends = []
            return
        }

        let palette: [Color] = [
            Color(.systemIndigo),
            Color(.systemTeal),
            Color(.systemPink),
            Color(.systemOrange),
            Color(.systemPurple),
            Color(.systemGreen)
        ]

        let sortedTotals = mergedTotals.sorted { $0.value > $1.value }
        categorySpends = sortedTotals.enumerated().map { index, entry in
            let color = palette[index % palette.count]
            return CategorySpendItem(label: entry.key, amount: entry.value, color: color)
        }
    }

    private func buildContributions() -> [(currencyCode: String, monthlyAmount: Double)] {
        var contributions: [(currencyCode: String, monthlyAmount: Double)] = []

        contributions.append(contentsOf: subscriptions.map { item in
            (currencyCode: item.currencyCode, monthlyAmount: monthlyEquivalent(for: item))
        })

        guard let userId else { return contributions }

        let groupContributions = groups.compactMap { group -> (String, Double)? in
            guard group.ownerId != userId,
                  let member = group.members.first(where: { $0.userId == userId }) else {
                return nil
            }
            let period = periodFromGroup(group)
            return (group.currencyCode, monthlyEquivalent(for: member.amount, period: period))
        }

        contributions.append(contentsOf: groupContributions)
        return contributions
    }

    private func initials(for text: String) -> String {
        let components = text
            .split(separator: " ")
            .filter { !$0.isEmpty }
        let letters = components.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }

    private func nextDateForDisplay(_ date: Date, period: SubscriptionPeriod?) -> Date {
        guard let period else { return date }
        var nextDate = date
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        while calendar.startOfDay(for: nextDate) < today {
            switch period {
            case .weekly:
                nextDate = calendar.date(byAdding: .day, value: 7, to: nextDate) ?? nextDate
            case .monthly:
                nextDate = calendar.date(byAdding: .month, value: 1, to: nextDate) ?? nextDate
            case .quarterly:
                nextDate = calendar.date(byAdding: .month, value: 3, to: nextDate) ?? nextDate
            case .yearly:
                nextDate = calendar.date(byAdding: .year, value: 1, to: nextDate) ?? nextDate
            }
        }
        return nextDate
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
        return nil
    }

    private func formattedCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }
}
