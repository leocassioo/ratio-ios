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
    @Published private(set) var groups: [SharedGroup] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var usdRate: ExchangeRate?
    @Published private(set) var eurRate: ExchangeRate?

    private let store: GroupsStore
    private let exchangeRateStore: ExchangeRateStore
    private let analytics: AnalyticsService
    private var listener: ListenerRegistration?
    private var exchangeRateListener: ListenerRegistration?
    private var eurRateListener: ListenerRegistration?

    init(
        store: GroupsStore? = nil,
        exchangeRateStore: ExchangeRateStore? = nil,
        analytics: AnalyticsService = .shared
    ) {
        self.store = store ?? GroupsStore()
        self.exchangeRateStore = exchangeRateStore ?? ExchangeRateStore()
        self.analytics = analytics
    }

    deinit {
        listener?.remove()
        exchangeRateListener?.remove()
        eurRateListener?.remove()
    }

    func startListening(userId: String) {
        listener?.remove()
        exchangeRateListener?.remove()
        eurRateListener?.remove()
        isLoading = true
        errorMessage = nil

        Task {
            try? await store.normalizeChargeDates(for: userId)
        }
        listener = store.listenGroups(for: userId) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let groups):
                    self?.groups = self?.sortedByNextCharge(groups) ?? groups
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
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
        listener = nil
        exchangeRateListener?.remove()
        exchangeRateListener = nil
        eurRateListener?.remove()
        eurRateListener = nil
        groups = []
        usdRate = nil
        eurRate = nil
    }

    func estimatedBRL(for amount: Double, currencyCode: String) -> Double? {
        switch currencyCode {
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
        default:
            return nil
        }
    }

    func estimatedAmount(for amount: Double, currencyCode: String, preferredCurrencyCode: String) -> Double? {
        convert(amount: amount, from: currencyCode, to: preferredCurrencyCode)
    }

    private func sortedByNextCharge(_ groups: [SharedGroup]) -> [SharedGroup] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        func nextDate(for group: SharedGroup) -> Date {
            group.chargeNextBillingDate ?? group.subscriptionNextBillingDate ?? Date.distantFuture
        }

        func hasOverdueMember(_ group: SharedGroup) -> Bool {
            group.members.contains { $0.status == .overdue }
        }

        return groups.sorted { lhs, rhs in
            let lhsOverdue = hasOverdueMember(lhs)
            let rhsOverdue = hasOverdueMember(rhs)
            if lhsOverdue != rhsOverdue {
                return lhsOverdue
            }

            let lhsDate = nextDate(for: lhs)
            let rhsDate = nextDate(for: rhs)
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
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

    func createGroup(
        name: String,
        subscription: SubscriptionItem,
        billingDay: Int?,
        notes: String?,
        serviceLogin: String?,
        servicePassword: String?,
        pixKey: String?,
        ownerPhoneNumber: String?,
        members: [GroupMemberDraft],
        ownerId: String
    ) async -> String? {
        let memberIds = members.compactMap { $0.userId }.unique() + [ownerId]
        let membersPreview: [[String: Any]] = members.map { member in
            let previewId = member.userId ?? member.id
            return [
                "id": previewId,
                "name": member.name,
                "amount": member.amountValue,
                "status": member.status.rawValue,
                "userId": member.userId as Any,
                "photoURL": member.photoURL as Any,
                "receiptURL": member.receiptURL as Any
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
            "ownerPhoneNumber": ownerPhoneNumber as Any,
            "memberIds": Array(Set(memberIds)),
            "membersPreview": membersPreview,
            "subscriptionId": subscription.id,
            "subscriptionName": subscription.name,
            "subscriptionCategory": subscription.category.rawValue,
            "subscriptionPeriod": subscription.period.rawValue,
            "subscriptionNextBillingDate": Timestamp(date: subscription.nextBillingDate),
            "subscriptionLogoURL": subscription.logoURL as Any,
            "chargeDay": billingDay as Any,
            "chargeNextBillingDate": Timestamp(date: computedChargeNextBillingDate(for: subscription, billingDay: billingDay)),
            "serviceLogin": serviceLogin as Any,
            "servicePassword": servicePassword as Any,
            "pixKey": pixKey as Any,
            "createdAt": FieldValue.serverTimestamp()
        ]

        do {
            let groupId = try await store.createGroup(data: data, members: members, ownerId: ownerId)
            analytics.track(.group_create, parameters: [
                "group_id": groupId,
                "category": subscription.category.rawValue,
                "period": subscription.period.rawValue,
                "currency": subscription.currencyCode,
                "source": "from_subscription"
            ])
            ReviewPromptService.shared.requestIfAppropriate(trigger: .groupCreated)
            return groupId
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func createGroupManual(
        name: String,
        category: GroupCategory,
        totalAmount: Double,
        currencyCode: String,
        period: SubscriptionPeriod,
        billingDay: Int?,
        notes: String?,
        serviceLogin: String?,
        servicePassword: String?,
        pixKey: String?,
        ownerPhoneNumber: String?,
        members: [GroupMemberDraft],
        ownerId: String
    ) async -> String? {
        let memberIds = members.compactMap { $0.userId }.unique() + [ownerId]
        let membersPreview: [[String: Any]] = members.map { member in
            let previewId = member.userId ?? member.id
            return [
                "id": previewId,
                "name": member.name,
                "amount": member.amountValue,
                "status": member.status.rawValue,
                "userId": member.userId as Any,
                "photoURL": member.photoURL as Any,
                "receiptURL": member.receiptURL as Any
            ]
        }

        let data: [String: Any] = [
            "name": name,
            "category": category.rawValue,
            "totalAmount": totalAmount,
            "currencyCode": currencyCode,
            "billingPeriod": period.label,
            "billingDay": billingDay as Any,
            "notes": notes as Any,
            "ownerId": ownerId,
            "ownerPhoneNumber": ownerPhoneNumber as Any,
            "memberIds": Array(Set(memberIds)),
            "membersPreview": membersPreview,
            "chargeDay": billingDay as Any,
            "chargeNextBillingDate": Timestamp(date: computedChargeNextBillingDate(for: period, billingDay: billingDay)),
            "serviceLogin": serviceLogin as Any,
            "servicePassword": servicePassword as Any,
            "pixKey": pixKey as Any,
            "createdAt": FieldValue.serverTimestamp()
        ]

        do {
            let groupId = try await store.createGroup(data: data, members: members, ownerId: ownerId)
            analytics.track(.group_create, parameters: [
                "group_id": groupId,
                "category": category.rawValue,
                "period": period.rawValue,
                "currency": currencyCode,
                "source": "manual"
            ])
            ReviewPromptService.shared.requestIfAppropriate(trigger: .groupCreated)
            return groupId
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func updateGroup(
        groupId: String,
        name: String,
        subscription: SubscriptionItem,
        billingDay: Int?,
        notes: String?,
        serviceLogin: String?,
        servicePassword: String?,
        pixKey: String?,
        ownerPhoneNumber: String?,
        members: [GroupMemberDraft],
        ownerId: String,
        removedMemberIds: [String] = []
    ) async {
        let memberIds = members.compactMap { $0.userId }.unique() + [ownerId]
        let membersPreview: [[String: Any]] = members.map { member in
            let previewId = member.userId ?? member.id
            return [
                "id": previewId,
                "name": member.name,
                "amount": member.amountValue,
                "status": member.status.rawValue,
                "userId": member.userId as Any,
                "photoURL": member.photoURL as Any,
                "receiptURL": member.receiptURL as Any
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
            "ownerPhoneNumber": ownerPhoneNumber as Any,
            "memberIds": Array(Set(memberIds)),
            "membersPreview": membersPreview,
            "subscriptionId": subscription.id,
            "subscriptionName": subscription.name,
            "subscriptionCategory": subscription.category.rawValue,
            "subscriptionPeriod": subscription.period.rawValue,
            "subscriptionNextBillingDate": Timestamp(date: subscription.nextBillingDate),
            "subscriptionLogoURL": subscription.logoURL as Any,
            "chargeDay": billingDay as Any,
            "chargeNextBillingDate": Timestamp(date: computedChargeNextBillingDate(for: subscription, billingDay: billingDay)),
            "serviceLogin": serviceLogin as Any,
            "servicePassword": servicePassword as Any,
            "pixKey": pixKey as Any,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        do {
            try await store.updateGroup(
                groupId: groupId,
                data: data,
                members: members,
                ownerId: ownerId,
                removedMemberIds: removedMemberIds
            )
            analytics.track(.group_edit, parameters: ["group_id": groupId])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateGroupManual(
        groupId: String,
        name: String,
        category: GroupCategory,
        totalAmount: Double,
        currencyCode: String,
        period: SubscriptionPeriod,
        billingDay: Int?,
        notes: String?,
        serviceLogin: String?,
        servicePassword: String?,
        pixKey: String?,
        ownerPhoneNumber: String?,
        members: [GroupMemberDraft],
        ownerId: String,
        removedMemberIds: [String] = []
    ) async {
        let memberIds = members.compactMap { $0.userId }.unique() + [ownerId]
        let membersPreview: [[String: Any]] = members.map { member in
            let previewId = member.userId ?? member.id
            return [
                "id": previewId,
                "name": member.name,
                "amount": member.amountValue,
                "status": member.status.rawValue,
                "userId": member.userId as Any,
                "photoURL": member.photoURL as Any,
                "receiptURL": member.receiptURL as Any
            ]
        }

        let data: [String: Any] = [
            "name": name,
            "category": category.rawValue,
            "totalAmount": totalAmount,
            "currencyCode": currencyCode,
            "billingPeriod": period.label,
            "billingDay": billingDay as Any,
            "notes": notes as Any,
            "ownerId": ownerId,
            "ownerPhoneNumber": ownerPhoneNumber as Any,
            "memberIds": Array(Set(memberIds)),
            "membersPreview": membersPreview,
            "subscriptionId": FieldValue.delete(),
            "subscriptionName": FieldValue.delete(),
            "subscriptionCategory": FieldValue.delete(),
            "subscriptionPeriod": FieldValue.delete(),
            "subscriptionNextBillingDate": FieldValue.delete(),
            "chargeDay": billingDay as Any,
            "chargeNextBillingDate": Timestamp(date: computedChargeNextBillingDate(for: period, billingDay: billingDay)),
            "serviceLogin": serviceLogin as Any,
            "servicePassword": servicePassword as Any,
            "pixKey": pixKey as Any,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        do {
            try await store.updateGroup(
                groupId: groupId,
                data: data,
                members: members,
                ownerId: ownerId,
                removedMemberIds: removedMemberIds
            )
            analytics.track(.group_edit, parameters: ["group_id": groupId])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteGroup(groupId: String) async {
        do {
            try await store.deleteGroup(groupId: groupId)
            analytics.track(.group_delete, parameters: ["group_id": groupId])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func computedChargeNextBillingDate(for subscription: SubscriptionItem, billingDay: Int?) -> Date {
        let calendar = Calendar.current
        let period = subscription.period
        let startOfToday = calendar.startOfDay(for: Date())
        let baseDate = calendar.startOfDay(for: subscription.nextBillingDate)

        func adjustedDate(from reference: Date) -> Date {
            guard let billingDay, billingDay > 0 else {
                return calendar.startOfDay(for: reference)
            }
            var components = calendar.dateComponents([.year, .month], from: reference)
            let dayRange = calendar.range(of: .day, in: .month, for: reference)
            components.day = min(billingDay, dayRange?.count ?? billingDay)
            return calendar.date(from: components) ?? calendar.startOfDay(for: reference)
        }

        var candidate: Date
        if period == .weekly {
            candidate = baseDate
        } else {
            candidate = adjustedDate(from: baseDate)
        }

        while candidate < startOfToday {
            switch period {
            case .weekly:
                candidate = calendar.date(byAdding: .day, value: 7, to: candidate) ?? candidate
            case .monthly:
                candidate = calendar.date(byAdding: .month, value: 1, to: candidate) ?? candidate
                candidate = adjustedDate(from: candidate)
            case .quarterly:
                candidate = calendar.date(byAdding: .month, value: 3, to: candidate) ?? candidate
                candidate = adjustedDate(from: candidate)
            case .yearly:
                candidate = calendar.date(byAdding: .year, value: 1, to: candidate) ?? candidate
                candidate = adjustedDate(from: candidate)
            case .oneTime:
                return candidate
            }
        }

        return candidate
    }

    private func computedChargeNextBillingDate(for period: SubscriptionPeriod?, billingDay: Int?) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        guard let period else { return startOfToday }

        if period == .weekly {
            return calendar.date(byAdding: .day, value: 7, to: startOfToday) ?? startOfToday
        }

        guard let billingDay, billingDay > 0 else {
            return startOfToday
        }

        func dateForDay(reference: Date) -> Date? {
            var components = calendar.dateComponents([.year, .month], from: reference)
            let dayRange = calendar.range(of: .day, in: .month, for: reference)
            components.day = min(billingDay, dayRange?.count ?? billingDay)
            return calendar.date(from: components)
        }

        guard var candidate = dateForDay(reference: now) else {
            return startOfToday
        }

        if candidate < startOfToday {
            let monthsToAdd: Int
            switch period {
            case .monthly:
                monthsToAdd = 1
            case .quarterly:
                monthsToAdd = 3
            case .yearly:
                monthsToAdd = 12
            case .weekly:
                monthsToAdd = 0
            case .oneTime:
                monthsToAdd = 1
            }
            let nextReference = calendar.date(byAdding: .month, value: monthsToAdd, to: now) ?? now
            candidate = dateForDay(reference: nextReference) ?? candidate
        }

        return candidate
    }
}
