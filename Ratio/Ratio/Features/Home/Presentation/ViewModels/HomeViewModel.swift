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
    @Published private(set) var monthlySpends: [MonthlySpendItem] = []
    @Published private(set) var monthlySpendsCurrencyCode: String = "BRL"
    @Published private(set) var hasSubscriptions = false
    @Published private(set) var hasGroups = false
    @Published private(set) var isLoading = false
    @Published private(set) var usdRate: ExchangeRate?
    @Published private(set) var eurRate: ExchangeRate?

    private let subscriptionsStore: SubscriptionsStore
    private let groupsStore: GroupsStore
    private let exchangeRateStore: ExchangeRateStore
    private let historyStore: BillingHistoryStore
    private let analytics: AnalyticsService
    private var listener: ListenerRegistration?
    private var groupsListener: ListenerRegistration?
    private var exchangeRateListener: ListenerRegistration?
    private var eurRateListener: ListenerRegistration?
    private var historyListener: ListenerRegistration?
    private var subscriptions: [SubscriptionItem] = []
    private var groups: [SharedGroup] = []
    private var billingHistoryItems: [BillingHistoryItem] = []
    private var userId: String?
    private var didLoadInitial = false
    private var didLoadSubscriptions = false
    private var didLoadGroups = false
    private var preferredCurrencyCode: String?
    private var isProAccess = false

    init(
        store: SubscriptionsStore? = nil,
        groupsStore: GroupsStore? = nil,
        exchangeRateStore: ExchangeRateStore? = nil,
        historyStore: BillingHistoryStore? = nil,
        analytics: AnalyticsService = .shared
    ) {
        self.subscriptionsStore = store ?? SubscriptionsStore()
        self.groupsStore = groupsStore ?? GroupsStore()
        self.exchangeRateStore = exchangeRateStore ?? ExchangeRateStore()
        self.historyStore = historyStore ?? BillingHistoryStore()
        self.analytics = analytics
    }

    deinit {
        listener?.remove()
        groupsListener?.remove()
        exchangeRateListener?.remove()
        historyListener?.remove()
    }

    func startListening(userId: String) {
        if self.userId != userId {
            didLoadInitial = false
            didLoadSubscriptions = false
            didLoadGroups = false
        }
        self.userId = userId
        listener?.remove()
        groupsListener?.remove()
        exchangeRateListener?.remove()
        historyListener?.remove()
        isLoading = true
        Task {
            try? await subscriptionsStore.normalizeNextBillingDates(userId: userId)
            try? await groupsStore.normalizeChargeDates(for: userId)

            if !didLoadInitial {
                let subscriptions = try? await subscriptionsStore.fetchSubscriptions(userId: userId)
                await MainActor.run {
                    if let subscriptions {
                        self.subscriptions = subscriptions
                        self.hasSubscriptions = !subscriptions.isEmpty
                        self.updateTotals()
                        self.updateInsights()
                        self.updateUpcomingPayments()
                        self.updateCategorySpends()
                    }
                    self.didLoadSubscriptions = true
                    self.updateLoadingState()
                }

                let groups = try? await groupsStore.fetchGroups(userId: userId)
                await MainActor.run {
                    if let groups {
                        self.groups = groups
                        self.hasGroups = !groups.isEmpty
                        self.updateTotals()
                        self.updateInsights()
                        self.updateUpcomingPayments()
                        self.updateCategorySpends()
                    }
                    self.didLoadGroups = true
                    self.updateLoadingState()
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
                    self?.didLoadSubscriptions = true
                    self?.updateLoadingState()
                    self?.updateTotals()
                    self?.updateInsights()
                    self?.updateUpcomingPayments()
                    self?.updateCategorySpends()
                case .failure:
                    self?.totalMonthlyAmount = 0
                    self?.hasSubscriptions = false
                    self?.didLoadSubscriptions = true
                    self?.updateLoadingState()
                }
            }
        }

        groupsListener = groupsStore.listenGroups(for: userId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let groups):
                    self?.groups = groups
                    self?.hasGroups = !groups.isEmpty
                    self?.didLoadGroups = true
                    self?.updateLoadingState()
                    self?.updateInsights()
                    self?.updateUpcomingPayments()
                    self?.updateCategorySpends()
                    self?.updateTotals()
                case .failure:
                    self?.groups = []
                    self?.hasGroups = false
                    self?.didLoadGroups = true
                    self?.updateLoadingState()
                }
            }
        }

        if isProAccess {
            startHistoryListening(userId: userId)
        }

        exchangeRateListener = exchangeRateStore.listenUsdRate { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let rate):
                    self?.usdRate = rate
                    self?.updateTotals()
                    self?.updateCategorySpends()
                    self?.updateMonthlySpends()
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
                    self?.updateTotals()
                    self?.updateCategorySpends()
                    self?.updateMonthlySpends()
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
        historyListener?.remove()
        listener = nil
        groupsListener = nil
        exchangeRateListener = nil
        eurRateListener = nil
        historyListener = nil
        totalMonthlyAmount = 0
        insights = []
        upcomingPayments = []
        categorySpends = []
        monthlySpends = []
        monthlySpendsCurrencyCode = "BRL"
        hasSubscriptions = false
        hasGroups = false
        isLoading = false
        didLoadSubscriptions = false
        didLoadGroups = false
        usdRate = nil
        eurRate = nil
        preferredCurrencyCode = nil
        billingHistoryItems = []
    }

    func setPreferredCurrencyCode(_ code: String?) {
        preferredCurrencyCode = code
        monthlySpendsCurrencyCode = code ?? "BRL"
        updateTotals()
        if isProAccess {
            updateMonthlySpends()
        }
    }

    func setProAccess(_ value: Bool) {
        guard isProAccess != value else { return }
        isProAccess = value
        if value {
            if let userId {
                startHistoryListening(userId: userId)
            }
            updateMonthlySpends()
        } else {
            historyListener?.remove()
            historyListener = nil
            billingHistoryItems = []
            monthlySpends = []
        }
    }

    func estimatedBRL(forAmount amount: Double, currencyCode: String) -> Double? {
        estimatedAmount(forAmount: amount, currencyCode: currencyCode, preferredCurrencyCode: "BRL")
    }

    func estimatedAmount(forAmount amount: Double, currencyCode: String, preferredCurrencyCode: String) -> Double? {
        return convert(amount: amount, from: currencyCode, to: preferredCurrencyCode)
    }

    func estimatedTotalsByCurrency(preferredCurrencyCode: String) -> [String: Double] {
        var estimates: [String: Double] = [:]
        totalsByCurrency.forEach { code, amount in
            if code == preferredCurrencyCode {
                return
            }
            if let estimated = estimatedAmount(forAmount: amount, currencyCode: code, preferredCurrencyCode: preferredCurrencyCode) {
                estimates[code] = estimated
            }
        }
        return estimates
    }

    private func updateLoadingState() {
        isLoading = !(didLoadSubscriptions && didLoadGroups)
    }

    private func updateTotals() {
        let contributions = buildContributions()
        guard let firstCurrency = contributions.first?.currencyCode, !firstCurrency.isEmpty else {
            totalMonthlyAmount = 0
            currencyCode = "BRL"
            hasMixedCurrencies = false
            totalsByCurrency = [:]
            updateUserProperties()
            return
        }

        totalsByCurrency = Dictionary(grouping: contributions, by: { $0.currencyCode })
            .mapValues { currencyItems in
                currencyItems.reduce(0) { partial, item in
                    partial + item.monthlyAmount
                }
            }
        let preferred = preferredCurrencyCode ?? "BRL"
        let supported = Set(["BRL", "USD", "EUR"])
        let currencyCodes = Set(totalsByCurrency.keys)
        if currencyCodes.isSubset(of: supported),
           supported.contains(preferred) {
            var convertedTotal: Double = 0
            var didConvertAll = true
            for (code, amount) in totalsByCurrency {
                guard let converted = convert(amount: amount, from: code, to: preferred) else {
                    didConvertAll = false
                    break
                }
                convertedTotal += converted
            }
            if didConvertAll {
                currencyCode = preferred
                hasMixedCurrencies = currencyCodes.count > 1
                totalMonthlyAmount = convertedTotal
                return
            }
        }

        let selectedCurrency = totalsByCurrency[preferred] != nil ? preferred : firstCurrency
        currencyCode = selectedCurrency
        hasMixedCurrencies = totalsByCurrency.keys.contains { $0 != selectedCurrency }
        totalMonthlyAmount = totalsByCurrency[selectedCurrency] ?? 0
        updateUserProperties()
    }

    private func updateUserProperties() {
        let subscriptionBucket = subscriptions.count >= 3 ? "3+" : String(subscriptions.count)
        let groupsBucket = groups.count >= 3 ? "3+" : String(groups.count)
        analytics.setUserProperty(.subscriptions_count, value: subscriptionBucket)
        analytics.setUserProperty(.groups_count, value: groupsBucket)
    }

    private func convert(amount: Double, from: String, to: String) -> Double? {
        if from == to {
            return amount
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
        case .oneTime:
            return amount
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
                icon: "person.3",
                detail: "Você tem \(subscriptionsWithoutGroup.count) assinaturas sem grupo. Crie um grupo para dividir custos ou organizar pagamentos.",
                destination: .subscriptions
            ))
        }

        let dueTodayTotal = dueTodaySubscriptions.count + dueTodayGroups.count
        if dueTodayTotal > 0 {
            items.append(HomeInsightItem(
                title: "\(dueTodayTotal) cobranças hoje",
                icon: "bell.badge",
                detail: "Há \(dueTodayTotal) cobranças vencendo hoje. Revise os pagamentos para evitar atrasos.",
                destination: hasSubscriptions ? .subscriptions : .groups
            ))
        }

        if pendingApprovals > 0 {
            items.append(HomeInsightItem(
                title: "\(pendingApprovals) pagamentos para aprovar",
                icon: "checkmark.seal",
                detail: "Existem \(pendingApprovals) pagamentos aguardando sua aprovação nos grupos.",
                destination: .groups
            ))
        }

        if savings > 0 {
            items.append(HomeInsightItem(
                title: "\(formattedCurrency(savings)) economizados",
                icon: "leaf",
                detail: "Economia estimada ao compartilhar assinaturas: \(formattedCurrency(savings)).",
                destination: nil
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
                subscriptionId: item.id,
                groupId: nil,
                name: item.name,
                initials: initials(for: item.name),
                amount: item.amount,
                currencyCode: item.currencyCode,
                dueDate: effectiveDate,
                period: item.period.label
            )
        }

        let groupItems = groups.compactMap { group -> UpcomingPaymentItem? in
            let isOwner = group.ownerId == userId
            let isManual = group.subscriptionId == nil
            if isOwner && !isManual {
                return nil
            }
            let dueDate = group.chargeNextBillingDate ?? group.subscriptionNextBillingDate
            guard let dueDate else { return nil }
            guard let member = group.members.first(where: { $0.userId == userId }) else { return nil }
            let effectiveDate = nextDateForDisplay(dueDate, period: periodFromGroup(group))
            return UpcomingPaymentItem(
                subscriptionId: nil,
                groupId: group.id,
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

        let preferredCurrency = preferredCurrencyCode ?? "BRL"
        if !isProAccess {
            categorySpends = buildMockCategorySpends(currencyCode: preferredCurrency)
            return
        }

        let subscriptionTotals = Dictionary(grouping: subscriptions, by: { $0.category.label })
            .mapValues { items in
                items.reduce(0) { partial, item in
                    guard let converted = convert(
                        amount: monthlyEquivalent(for: item),
                        from: item.currencyCode,
                        to: preferredCurrency
                    ) else {
                        return partial
                    }
                    return partial + converted
                }
            }

        let groupTotals = groups.reduce(into: [String: Double]()) { partial, group in
            let isOwner = group.ownerId == userId
            let isManual = group.subscriptionId == nil
            guard (!isOwner || isManual),
                  let member = group.members.first(where: { $0.userId == userId }) else {
                return
            }
            let period = periodFromGroup(group)
            let amount = monthlyEquivalent(for: member.amount, period: period)
            guard let converted = convert(
                amount: amount,
                from: group.currencyCode,
                to: preferredCurrency
            ) else {
                return
            }
            partial[group.category.label, default: 0] += converted
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
            return CategorySpendItem(label: entry.key, amount: entry.value, currencyCode: preferredCurrency, color: color)
        }
    }

    private func buildMockCategorySpends(currencyCode: String) -> [CategorySpendItem] {
        let base: Double = currencyCode == "USD" ? 18 : currencyCode == "EUR" ? 16 : 90
        let values: [(String, Double, Color)] = [
            ("Streaming", base * 1.4, Color(.systemIndigo)),
            ("Software", base * 1.1, Color(.systemTeal)),
            ("Fitness", base * 0.9, Color(.systemPink)),
            ("Outros", base * 0.6, Color(.systemOrange))
        ]
        return values.map { label, amount, color in
            CategorySpendItem(label: label, amount: amount, currencyCode: currencyCode, color: color)
        }
    }

    private func updateMonthlySpends() {
        let preferred = preferredCurrencyCode ?? "BRL"
        monthlySpendsCurrencyCode = preferred

        if !isProAccess {
            monthlySpends = buildMockMonthlySpends(currencyCode: preferred)
            return
        }

        guard !billingHistoryItems.isEmpty else {
            monthlySpends = []
            return
        }

        let calendar = Calendar.current
        let now = Date()
        guard let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            monthlySpends = []
            return
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "MMM"

        monthlySpends = (-5...0).compactMap { offset -> MonthlySpendItem? in
            guard let monthStart = calendar.date(byAdding: .month, value: offset, to: startOfCurrentMonth) else {
                return nil
            }
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
            let monthItems = billingHistoryItems.filter { $0.occurredAt >= monthStart && $0.occurredAt < nextMonth }
            let total = monthItems.reduce(0.0) { partial, item in
                if let converted = convert(
                    amount: item.amount,
                    from: item.currencyCode,
                    to: preferred
                ) {
                    return partial + converted
                }
                return partial
            }
            return MonthlySpendItem(
                monthStart: monthStart,
                label: formatter.string(from: monthStart).capitalized,
                amount: total,
                currencyCode: preferred
            )
        }
    }

    private func buildMockMonthlySpends(currencyCode: String) -> [MonthlySpendItem] {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return []
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "MMM"

        let base: Double = currencyCode == "USD" ? 45 : currencyCode == "EUR" ? 40 : 180
        let deltas: [Double] = [0.8, 1.1, 0.95, 1.2, 1.05, 1.3]

        return (-5...0).compactMap { offset -> MonthlySpendItem? in
            guard let monthStart = calendar.date(byAdding: .month, value: offset, to: startOfCurrentMonth) else {
                return nil
            }
            let factorIndex = max(0, min(deltas.count - 1, offset + 5))
            let amount = (base * deltas[factorIndex])
            return MonthlySpendItem(
                monthStart: monthStart,
                label: formatter.string(from: monthStart).capitalized,
                amount: amount,
                currencyCode: currencyCode
            )
        }
    }

    private func startHistoryListening(userId: String) {
        historyListener?.remove()
        historyListener = historyStore.listenHistory(for: userId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let items):
                    self?.billingHistoryItems = items
                    self?.updateMonthlySpends()
                case .failure:
                    self?.billingHistoryItems = []
                    self?.monthlySpends = []
                }
            }
        }
    }

    private func buildContributions() -> [(currencyCode: String, monthlyAmount: Double)] {
        var contributions: [(currencyCode: String, monthlyAmount: Double)] = []

        contributions.append(contentsOf: subscriptions.map { item in
            (currencyCode: item.currencyCode, monthlyAmount: monthlyEquivalent(for: item))
        })

        guard let userId else { return contributions }

        let groupContributions = groups.compactMap { group -> (String, Double)? in
            let isOwner = group.ownerId == userId
            let isManual = group.subscriptionId == nil
            guard (!isOwner || isManual),
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
            case .oneTime:
                return date
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
        if label.contains("única") || label.contains("unica") {
            return .oneTime
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
