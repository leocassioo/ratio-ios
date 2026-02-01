//
//  OnboardingView.swift
//  Ratio
//
//  Created by Codex on 23/12/25.
//

import SwiftUI

struct OnboardingView: View {
    let showsFinishButton: Bool
    let onFinish: () -> Void
    @State private var currentPage = 0
    @StateObject private var viewModel = OnboardingViewModel()
    private let analytics = AnalyticsService.shared

    init(showsFinishButton: Bool = true, onFinish: @escaping () -> Void) {
        self.showsFinishButton = showsFinishButton
        self.onFinish = onFinish
    }

    var body: some View {
        let pages: [(String, String, String)] = [
            ("creditcard", "Controle suas assinaturas", "Centralize seus serviços e acompanhe o valor total mensal."),
            ("person.2.fill", "Divida custos com facilidade", "Crie grupos e organize cobranças entre amigos ou família."),
            ("bell.badge.fill", "Lembretes no tempo certo", "Receba avisos de cobrança e evite atrasos."),
            ("checkmark.circle", "Pronto para começar", "Cadastre sua primeira assinatura e acompanhe tudo em um só lugar.")
        ]
        let totalPages = pages.count
        let lastPageIndex = totalPages - 1
        let indicatorPages = showsFinishButton ? totalPages - 1 : totalPages

        ZStack {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    if index == 1 {
                        OnboardingAIPageView(
                            systemImage: page.0,
                            title: page.1,
                            description: page.2
                        )
                        .tag(index)
                    } else if index == totalPages - 1 {
                        VStack(spacing: 24) {
                            OnboardingPageView(
                                systemImage: page.0,
                                title: page.1,
                                description: page.2
                            )
                            if showsFinishButton {
                                Button(action: handleFinish) {
                                    Text("Começar a usar")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.accentColor, in: Capsule())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 32)
                                }
                                .padding(.bottom, 32)
                            }
                        }
                        .tag(index)
                    } else {
                        OnboardingPageView(
                            systemImage: page.0,
                            title: page.1,
                            description: page.2
                        )
                        .tag(index)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 12) {
                Spacer()
                if !(showsFinishButton && currentPage == lastPageIndex) {
                    HStack {
                        Button {
                            withAnimation {
                                currentPage = max(0, currentPage - 1)
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title2.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .frame(width: 44, height: 44)
                        .foregroundStyle(currentPage == 0 ? .secondary : Color.accentColor)
                        .disabled(currentPage == 0)

                        Spacer()

                        Button {
                            withAnimation {
                                currentPage = min(lastPageIndex, currentPage + 1)
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.title2.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .frame(width: 44, height: 44)
                        .foregroundStyle(currentPage == lastPageIndex ? .secondary : Color.accentColor)
                        .disabled(currentPage == lastPageIndex)
                    }
                    .padding(.horizontal, 32)
                }
                if currentPage < indicatorPages {
                    HStack(spacing: 8) {
                        ForEach(0..<indicatorPages, id: \.self) { index in
                            Circle()
                                .frame(width: 8, height: 8)
                                .foregroundColor(index == currentPage ? .accentColor : .gray.opacity(0.3))
                        }
                    }
                    .padding(.bottom, 24)
                    .animation(.easeInOut, value: currentPage)
                }
            }
        }
        .onAppear {
            if showsFinishButton {
                analytics.screenView(.screen_onboarding)
            } else {
                analytics.screenView(.screen_onboarding_tutorial)
            }
            viewModel.trackOnboardingView(stepIndex: currentPage)
        }
        .onChange(of: currentPage) { _, newValue in
            viewModel.trackOnboardingView(stepIndex: newValue)
            if newValue == 1 {
                analytics.screenView(.screen_onboarding_ai)
            }
        }
    }

    private func handleFinish() {
        viewModel.trackOnboardingComplete()
        onFinish()
    }
}
