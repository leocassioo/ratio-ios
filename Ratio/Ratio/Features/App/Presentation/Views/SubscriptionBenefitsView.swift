//
//  SubscriptionBenefitsView.swift
//  Ratio
//
//  Created by Codex on 23/12/25.
//

import SwiftUI

struct SubscriptionBenefitsView: View {
    let source: PaywallSource
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var selectedPlan: SubscriptionProduct = .annual
    @State private var currentBenefitPage: Int = 0
    @State private var showSuccess = false
    @State private var isRestoring = false
    @State private var restoreMessage: String?
    @State private var showRestoreAlert = false
    private let analytics = AnalyticsService.shared

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        headerCarousel
                            .padding(.top, 8)

                        planList
                            .padding(.horizontal)

                        Spacer(minLength: 140)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .background(
                    Color(.systemBackground)
                        .ignoresSafeArea(edges: .bottom)
                )

                subscribeSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 2)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                }
            }
        }
        .fullScreenCover(isPresented: $showSuccess) {
            SubscriptionSuccessView {
                dismiss()
            }
        }
        .onAppear {
            analytics.screenView(.screen_subscription_benefits)
            analytics.track(.paywall_open, parameters: ["source": source.rawValue])
        }
    }

    private var headerCarousel: some View {
        VStack(spacing: 8) {
            Text("Ratio Pro")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            Text("Aprimore sua gestão com insights inteligentes e recursos avançados.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            let totalBenefitPages = 4

            TabView(selection: $currentBenefitPage) {
                BenefitCardView(
                    icon: "sparkles",
                    title: "Análises com IA",
                    description: "Receba insights sobre gastos e oportunidades de economia."
                )
                .tag(0)

                BenefitCardView(
                    icon: "bell.badge",
                    title: "Lembretes inteligentes",
                    description: "Configure avisos avançados para não perder cobranças."
                )
                .tag(1)

                BenefitCardView(
                    icon: "person.3.sequence",
                    title: "Gestão de grupos",
                    description: "Recursos avançados para administrar cobranças compartilhadas."
                )
                .tag(2)

                BenefitCardView(
                    icon: "chart.pie",
                    title: "Relatórios completos",
                    description: "Acompanhe sua evolução mensal com relatórios detalhados."
                )
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 150)

            HStack(spacing: 6) {
                ForEach(0..<totalBenefitPages, id: \.self) { index in
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundColor(index == currentBenefitPage ? .primary : .secondary.opacity(0.4))
                }
            }
            .padding(.bottom, 8)
        }
    }

    private var planList: some View {
        VStack(spacing: 12) {
            PlanRowView(
                title: SubscriptionProduct.annual.displayName,
                detail: planDetail(for: .annual, fallback: " / ano"),
                highlight: annualHighlight(),
                isSelected: selectedPlan == .annual
            ) {
                selectedPlan = .annual
            }

            PlanRowView(
                title: SubscriptionProduct.semiannual.displayName,
                detail: planDetail(for: .semiannual, fallback: " / semestre"),
                highlight: nil,
                isSelected: selectedPlan == .semiannual
            ) {
                selectedPlan = .semiannual
            }

            PlanRowView(
                title: SubscriptionProduct.monthly.displayName,
                detail: planDetail(for: .monthly, fallback: " / mês"),
                highlight: nil,
                isSelected: selectedPlan == .monthly
            ) {
                selectedPlan = .monthly
            }
        }
    }

    private var subscribeSection: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    let planKey = analyticsPlanKey(selectedPlan)
                    analytics.track(.paywall_cta_tap, parameters: ["plan": planKey])
                    analytics.track(.subscription_start, parameters: [
                        "plan": planKey,
                        "price": subscriptionManager.displayPrice(for: selectedPlan)
                    ])
                    let result = await subscriptionManager.purchase(product: selectedPlan)
                    if case .success = result {
                        analytics.track(.subscription_success)
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            showSuccess = true
                        }
                    }
                }
            } label: {
                if subscriptionManager.isPurchasing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                } else {
                    Text(buttonTitle(for: selectedPlan))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                }
            }
            .buttonStyle(.borderedProminent)

            Text("Assinaturas serão cobradas automaticamente até o cancelamento.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    analytics.track(.restore_tap)
                    isRestoring = true
                    await subscriptionManager.refreshEntitlements()
                    isRestoring = false

                    if subscriptionManager.hasProAccess {
                        analytics.track(.restore_success)
                        restoreMessage = "Assinatura restaurada com sucesso."
                        showSuccess = true
                    } else {
                        restoreMessage = "Nenhuma assinatura ativa encontrada."
                        showRestoreAlert = true
                    }
                }
            } label: {
                if isRestoring {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Restaurando...")
                    }
                } else {
                    Text("Restaurar compras")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .disabled(isRestoring || subscriptionManager.isPurchasing)

            HStack(spacing: 16) {
                Link("Termos de uso", destination: URL(string: "https://uaipixel.com/legal/ratio/terms")!)
                Link("Política de privacidade", destination: URL(string: "https://uaipixel.com/legal/ratio/privacy")!)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.bottom, 0)
        .alert(restoreMessage ?? "", isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) { }
        }
    }

    private func annualHighlight() -> String? {
        if let discount = subscriptionManager.annualDiscountPercentage(), discount > 0 {
            return "Economize \(discount)%"
        }
        return SubscriptionProduct.annual.promotionalBadge
    }

    private func planDetail(for product: SubscriptionProduct, fallback: String) -> String {
        if let trialDays = product.trialDays {
            return "\(trialDays) dias grátis · \(subscriptionManager.displayPrice(for: product))"
        }
        return subscriptionManager.displayPrice(for: product) + fallback
    }

    private func buttonTitle(for product: SubscriptionProduct) -> String {
        switch product {
        case .annual:
            return "Assinar anual"
        case .semiannual:
            return "Assinar semestral"
        case .monthly:
            return "Assinar mensal"
        }
    }

    private func analyticsPlanKey(_ product: SubscriptionProduct) -> String {
        switch product {
        case .monthly:
            return "monthly"
        case .semiannual:
            return "semiannual"
        case .annual:
            return "annual"
        }
    }
}
