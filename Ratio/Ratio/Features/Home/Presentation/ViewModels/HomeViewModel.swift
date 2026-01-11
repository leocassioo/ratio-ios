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

    private let subscriptionsStore: SubscriptionsStore
    private let groupsStore: GroupsStore
    private var listener: ListenerRegistration?
    private var groupsListener: ListenerRegistration?
    private var subscriptions: [SubscriptionItem] = []
    private var groups: [Group] = []
    private var userId: String?

    init(store: SubscriptionsStore? = nil, groupsStore: GroupsStore? = nil) {
        self.subscriptionsStore = store ?? SubscriptionsStore()
        self.groupsStore = groupsStore ?? GroupsStore()
    }

    deinit {
        listener?.remove()
        groupsListener?.remove()
    }

    func startListening(userId: String) {
        self.userId = userId
        listener?.remove()
        groupsListener?.remove()
        Task {
            try? await subscriptionsStore.normalizeNextBillingDates(userId: userId)
            try? await groupsStore.normalizeChargeDates(for: userId)
        }
        listener = subscriptionsStore.listenSubscriptions(for: userId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let items):
                    self?.subscriptions = items
                    self?.updateTotals(with: items)
                    self?.updateInsights()
                    self?.updateUpcomingPayments()
                    self?.updateCategorySpends()
                case .failure:
                    self?.totalMonthlyAmount = 0
                }
            }
        }

        groupsListener = groupsStore.listenGroups(for: userId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let groups):
                    self?.groups = groups
                    self?.updateInsights()
                    self?.updateUpcomingPayments()
                    self?.updateCategorySpends()
                case .failure:
                    self?.groups = []
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
    }

    private func updateTotals(with items: [SubscriptionItem]) {
        guard let firstCurrency = items.first?.currencyCode, !firstCurrency.isEmpty else {
            totalMonthlyAmount = 0
            currencyCode = "BRL"
            hasMixedCurrencies = false
            totalsByCurrency = [:]
            return
        }

        currencyCode = firstCurrency
        hasMixedCurrencies = items.contains { $0.currencyCode != firstCurrency }
        totalsByCurrency = Dictionary(grouping: items, by: { $0.currencyCode })
            .mapValues { currencyItems in
                currencyItems.reduce(0) { partial, item in
                    partial + monthlyEquivalent(for: item)
                }
            }
        totalMonthlyAmount = totalsByCurrency[firstCurrency] ?? 0
    }

    private func monthlyEquivalent(for item: SubscriptionItem) -> Double {
        switch item.period {
        case .weekly:
            return item.amount * 4.33
        case .monthly:
            return item.amount
        case .quarterly:
            return item.amount / 3
        case .yearly:
            return item.amount / 12
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
        guard !subscriptions.isEmpty else {
            categorySpends = []
            return
        }

        let grouped = Dictionary(grouping: subscriptions, by: { $0.category })
        let sortedCategories = SubscriptionCategory.allCases.sorted { $0.label < $1.label }
        let palette: [Color] = [
            Color(.systemIndigo),
            Color(.systemTeal),
            Color(.systemPink),
            Color(.systemOrange),
            Color(.systemPurple),
            Color(.systemGreen)
        ]

        var items: [CategorySpendItem] = []
        var totals: [(category: SubscriptionCategory, total: Double)] = []
        for category in sortedCategories {
            guard let categoryItems = grouped[category] else { continue }
            let total = categoryItems.reduce(0) { partial, item in
                partial + monthlyEquivalent(for: item)
            }
            totals.append((category: category, total: total))
        }

        let sortedTotals = totals.sorted { $0.total > $1.total }
        for (index, entry) in sortedTotals.enumerated() {
            let color = palette[index % palette.count]
            items.append(CategorySpendItem(label: entry.category.label, amount: entry.total, color: color))
        }

        categorySpends = items
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

    private func periodFromGroup(_ group: Group) -> SubscriptionPeriod? {
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
