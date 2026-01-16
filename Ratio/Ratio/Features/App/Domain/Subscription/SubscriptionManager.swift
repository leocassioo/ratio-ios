//
//  SubscriptionManager.swift
//  Ratio
//
//  Created by Codex on 23/12/25.
//

import Combine
import Foundation
import StoreKit

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published private(set) var isProUser: Bool = PreferencesStore.shared.isProUser()
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isPurchasing: Bool = false
    @Published private(set) var lastError: String?

    private var products: [SubscriptionProduct: Product] = [:]

    var hasProAccess: Bool {
        isProUser || RemoteConfigService.shared.premiumBypassEnabled
    }

    init() {
        Task {
            await loadProducts()
            await refreshEntitlements()
            await listenForTransactions()
        }
    }

    func refreshEntitlements() async {
        isLoading = true
        defer { isLoading = false }

        do {
            var foundActiveSubscription = false
            for await result in Transaction.currentEntitlements {
                guard case .verified(let transaction) = result else { continue }
                if SubscriptionProduct.allCases.contains(where: { $0.rawValue == transaction.productID }) {
                    foundActiveSubscription = true
                    updateProStatus(true)
                    return
                }
            }
            if !foundActiveSubscription {
                updateProStatus(false)
            }
        } catch {
            lastError = "Não foi possível atualizar a assinatura."
        }
    }

    func purchase(product: SubscriptionProduct) async -> PurchaseResult {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let storeProduct = try await loadProduct(for: product)
            let result = try await storeProduct.purchase()

            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    if SubscriptionProduct.allCases.contains(where: { $0.rawValue == transaction.productID }) {
                        updateProStatus(true)
                    }
                    await transaction.finish()
                    return .success
                }
                return .failed(NSError(domain: "SubscriptionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Transação inválida."]))
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed(NSError(domain: "SubscriptionManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Resultado desconhecido."]))
            }
        } catch {
            lastError = "Não foi possível concluir a compra."
            return .failed(error)
        }
    }

    func displayPrice(for product: SubscriptionProduct) -> String {
        if let storeProduct = products[product] {
            return storeProduct.displayPrice
        }
        return "R$ --"
    }

    func annualDiscountPercentage() -> Int? {
        guard let annualProduct = products[.annual],
              let monthlyProduct = products[.monthly] else {
            return nil
        }

        let annualPrice = NSDecimalNumber(decimal: annualProduct.price).doubleValue
        let monthlyYearlyPrice = NSDecimalNumber(decimal: monthlyProduct.price).doubleValue * 12
        guard monthlyYearlyPrice > 0 else { return nil }
        let discount = (1 - (annualPrice / monthlyYearlyPrice)) * 100
        return Int(discount.rounded())
    }

    func hasTrial(_ product: SubscriptionProduct) -> Bool {
        product.trialDays != nil
    }

    func getProduct(_ product: SubscriptionProduct) -> Product? {
        products[product]
    }

    private func loadProducts() async {
        do {
            let ids = SubscriptionProduct.allCases.map { $0.rawValue }
            let fetched = try await Product.products(for: ids)
            var map: [SubscriptionProduct: Product] = [:]
            for product in SubscriptionProduct.allCases {
                if let storeProduct = fetched.first(where: { $0.id == product.rawValue }) {
                    map[product] = storeProduct
                }
            }
            products = map
        } catch {
            lastError = "Não foi possível carregar os planos."
        }
    }

    private func loadProduct(for subscriptionProduct: SubscriptionProduct) async throws -> Product {
        if let cached = products[subscriptionProduct] {
            return cached
        }
        let fetched = try await Product.products(for: [subscriptionProduct.rawValue])
        guard let product = fetched.first else {
            throw NSError(domain: "SubscriptionManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Produto não encontrado."])
        }
        products[subscriptionProduct] = product
        return product
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            if SubscriptionProduct.allCases.contains(where: { $0.rawValue == transaction.productID }) {
                updateProStatus(true)
            }
            await transaction.finish()
        }
    }

    private func updateProStatus(_ value: Bool) {
        isProUser = value
        PreferencesStore.shared.setIsProUser(value)
    }
}
