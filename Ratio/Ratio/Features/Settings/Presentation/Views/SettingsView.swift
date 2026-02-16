//
//  SettingsView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI
import FirebaseAuth
import StoreKit
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var router: AppRouter
    @AppStorage(PreferencesStore.PrefKey.appTheme) private var appThemeRaw: String = AppTheme.system.rawValue
    @AppStorage(PreferencesStore.PrefKey.appLanguage) private var appLanguageRaw: String = AppLanguage.system.rawValue
    @AppStorage(PreferencesStore.PrefKey.primaryCurrencyCode) private var primaryCurrencyCodeRaw: String = "BRL"
    @State private var showSignOutConfirm = false
    @State private var isSigningOut = false
    @State private var showWhatsNewError = false
    @State private var isLoadingWhatsNew = false
    @State private var didLogScreen = false
    private let analytics = AnalyticsService.shared

    private var appTheme: Binding<AppTheme> {
        Binding(
            get: { AppTheme(rawValue: appThemeRaw) ?? .system },
            set: { appThemeRaw = $0.rawValue }
        )
    }

    private var appLanguage: Binding<AppLanguage> {
        Binding(
            get: { AppLanguage(rawValue: appLanguageRaw) ?? .system },
            set: { appLanguageRaw = $0.rawValue }
        )
    }

    private var primaryCurrency: Binding<PrimaryCurrencyOption> {
        Binding(
            get: { PrimaryCurrencyOption(rawValue: primaryCurrencyCodeRaw) ?? .brl },
            set: { primaryCurrencyCodeRaw = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section {
                if let user = authViewModel.user {
                    Button {
                        analytics.track(.settings_profile_open)
                        router.push(.editProfile, in: .settings)
                    } label: {
                        HStack(spacing: 12) {
                            if let url = user.photoURL {
                                CachedAsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                    case .failure, .empty:
                                        Image(systemName: "person.crop.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(width: 32, height: 32)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle")
                                    .foregroundStyle(.secondary)
                            }

                            Text("Perfil")

                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button {
                    router.push(.redeemInvite, in: .settings)
                } label: {
                    Label("Resgatar convite de grupo", systemImage: "ticket")
                }
            } header: {
                Text("Conta")
            }

            Section {
                Picker("Moeda principal", selection: primaryCurrency) {
                    ForEach(PrimaryCurrencyOption.allCases) { currency in
                        Text(currency.label).tag(currency)
                    }
                }
            } header: {
                Text("Moeda")
            } footer: {
                Text("Usamos essa moeda para destacar os totais e estimativas.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    router.push(.billingHistory, in: .settings)
                } label: {
                    Label("Histórico de cobranças", systemImage: "clock.arrow.circlepath")
                }
            } header: {
                Text("Histórico")
            } footer: {
                Text("Em breve: histórico completo de assinaturas e grupos.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !subscriptionManager.hasProAccess {
                Section {
                    Button {
                        router.present(.subscriptionBenefits(source: .settings))
                    } label: {
                        Label("Ratio Pro", systemImage: "crown.fill")
                    }
                } header: {
                    Text("Assinatura")
                } footer: {
                    Text("Conheça os benefícios do Ratio Pro e escolha seu plano.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    analytics.track(.settings_help_open, parameters: ["source": "tutorial"])
                    router.push(.onboardingTutorial, in: .settings)
                } label: {
                    Label("Tutorial rápido", systemImage: "questionmark.circle")
                }

                Button {
                    openWhatsNew()
                } label: {
                    Label("Novidades da versão", systemImage: "sparkles")
                }
                .disabled(isLoadingWhatsNew)
            } header: {
                Text("Ajuda e tutorial")
            } footer: {
                Text("Revise as principais funções do app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Tema do app", selection: appTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.label).tag(theme)
                    }
                }
            } header: {
                Text("Aparência")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Personalize o visual do app.")
                }
            }

            Section {
                HStack {
                    Text("Versão do app")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(.secondary)
                }
                Button {
                    openStoreReview()
                } label: {
                    Label("Avaliar o app", systemImage: "star.bubble")
                }
                Link("Termos de uso", destination: URL(string: "https://uaipixel.com/legal/ratio/terms")!)
                Link("Política de privacidade", destination: URL(string: "https://uaipixel.com/legal/ratio/privacy")!)
            } header: {
                Text("Sobre")
            } footer: {
                Text("Ratio © 2026 Red Pixel Tecnologia")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            }

            Section {
                Button(role: .destructive) {
                    showSignOutConfirm = true
                } label: {
                    Text("Sair")
                }
            }

        }
        .disabled(isSigningOut)
        .navigationTitle("Ajustes")
        .onAppear {
            if !didLogScreen {
                analytics.screenView(.screen_settings)
                analytics.track(.settings_open)
                didLogScreen = true
            }
        }
        .onDisappear {
            didLogScreen = false
        }
        .onChange(of: primaryCurrencyCodeRaw) { _, newValue in
            analytics.track(.settings_currency_change, parameters: ["currency": newValue])
        }
        .alert("Sair da conta?", isPresented: $showSignOutConfirm) {
            Button("Cancelar", role: .cancel) {}
            Button("Sair", role: .destructive) {
                isSigningOut = true
                authViewModel.signOut()
            }
        } message: {
            Text("Você precisará fazer login novamente para acessar o app.")
        }
        .alert("Novidades indisponíveis", isPresented: $showWhatsNewError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Não foi possível carregar as novidades agora.")
        }
        .overlay {
            if isSigningOut {
                ZStack {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView("Saindo...")
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .onReceive(authViewModel.$user) { user in
            if user == nil {
                isSigningOut = false
                router.selectedTab = .home
                router.homePath = NavigationPath()
                router.subscriptionsPath = NavigationPath()
                router.groupsPath = NavigationPath()
                router.advisorPath = NavigationPath()
                router.settingsPath = NavigationPath()
                router.authPath = NavigationPath()
                router.pendingGroupId = nil
                router.dismissSheet()
                router.dismissFullScreenCover()
            }
        }
    }

    private func openWhatsNew() {
        guard !isLoadingWhatsNew else { return }
        isLoadingWhatsNew = true
        Task { @MainActor in
            _ = await RemoteConfigService.shared.fetchAndActivate()
            guard let payload = RemoteConfigService.shared.whatsNewPayload else {
                showWhatsNewError = true
                isLoadingWhatsNew = false
                return
            }
            let slides = payload.slides(for: Locale.current)
            guard !slides.isEmpty else {
                showWhatsNewError = true
                isLoadingWhatsNew = false
                return
            }
            let currentVersion = AppVersion.current
            let isOutdated = payload.minVersion.map { AppVersion.isLower(currentVersion, than: $0) } ?? false
            let state = WhatsNewState(payload: payload, slides: slides, isOutdated: isOutdated, source: .settings)
            router.present(.whatsNew(state: state))
            isLoadingWhatsNew = false
        }
    }

    private func openStoreReview() {
        guard let url = URL(string: "itms-apps://apps.apple.com/us/app/ratio-dividir-contas-e-gastos/id6757924426?action=write-review") else {
            return
        }
        UIApplication.shared.open(url)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
        .environmentObject(SubscriptionManager.shared)
        .environmentObject(AppRouter())
}
