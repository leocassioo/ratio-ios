//
//  GroupPaymentsViewModel.swift
//  Ratio
//
//  Created by Codex on 08/01/26.
//

import Combine
import FirebaseFirestore
import Foundation
import UIKit

@MainActor
final class GroupPaymentsViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var userPixKey: String?
    @Published private(set) var usdRate: ExchangeRate?
    @Published private(set) var eurRate: ExchangeRate?

    private let store: GroupPaymentsStore
    private let usersStore: UsersStore
    private let exchangeRateStore: ExchangeRateStore
    private let analytics: AnalyticsService
    private var usdRateListener: ListenerRegistration?
    private var eurRateListener: ListenerRegistration?

    init(
        store: GroupPaymentsStore? = nil,
        usersStore: UsersStore = UsersStore(),
        exchangeRateStore: ExchangeRateStore? = nil,
        analytics: AnalyticsService = .shared
    ) {
        self.store = store ?? GroupPaymentsStore()
        self.usersStore = usersStore
        self.exchangeRateStore = exchangeRateStore ?? ExchangeRateStore()
        self.analytics = analytics
    }

    deinit {
        usdRateListener?.remove()
        eurRateListener?.remove()
    }

    func submitPayment(groupId: String, memberId: String, receiptData: Data?) async {
        isLoading = true
        errorMessage = nil

        do {
            analytics.track(.payment_submit, parameters: [
                "group_id": groupId,
                "member_id": memberId,
                "has_receipt": receiptData != nil
            ])
            var receiptURL: String?
            if let receiptData {
                let prepared = prepareReceiptData(receiptData)
                receiptURL = try await store.uploadReceipt(groupId: groupId, memberId: memberId, data: prepared)
            }
            try await store.submitPayment(groupId: groupId, memberId: memberId, receiptURL: receiptURL)
            analytics.track(.payment_submit_success, parameters: [
                "group_id": groupId,
                "member_id": memberId,
                "has_receipt": receiptData != nil
            ])
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            analytics.track(.payment_submit_error, parameters: [
                "group_id": groupId,
                "member_id": memberId,
                "reason": errorReason(from: error)
            ])
            isLoading = false
        }
    }

    func approvePayment(groupId: String, memberId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            try await store.approvePayment(groupId: groupId, memberId: memberId)
            analytics.track(.payment_approve, parameters: [
                "group_id": groupId,
                "member_id": memberId
            ])
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func fetchUserPixKey(userId: String) async {
        do {
            if let profile = try await usersStore.fetchUserProfile(userId: userId) {
                userPixKey = profile.pixKey
            }
        } catch {
            print("Error fetching user profile: \(error)")
        }
    }

    func startListeningRates() {
        usdRateListener?.remove()
        eurRateListener?.remove()

        usdRateListener = exchangeRateStore.listenUsdRate { [weak self] result in
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

    func stopListeningRates() {
        usdRateListener?.remove()
        eurRateListener?.remove()
        usdRateListener = nil
        eurRateListener = nil
    }

    func estimatedAmount(for amount: Double, currencyCode: String, preferredCurrencyCode: String) -> Double? {
        convert(amount: amount, from: currencyCode, to: preferredCurrencyCode)
    }

    private func prepareReceiptData(_ data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let maxDimension: CGFloat = 1024
        let resized = resizeImage(image, maxDimension: maxDimension)
        return compressImageData(resized, maxBytes: 100_000) ?? data
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

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func compressImageData(_ image: UIImage, maxBytes: Int) -> Data? {
        var quality: CGFloat = 0.45
        var data = image.jpegData(compressionQuality: quality)
        while let current = data, current.count > maxBytes, quality > 0.3 {
            quality -= 0.08
            data = image.jpegData(compressionQuality: quality)
        }
        return data
    }

    private func errorReason(from error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain):\(nsError.code)"
    }
}
