//
//  SettingsView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var router: AppRouter
    @AppStorage(PreferencesStore.PrefKey.appTheme) private var appThemeRaw: String = AppTheme.system.rawValue
    @AppStorage(PreferencesStore.PrefKey.appLanguage) private var appLanguageRaw: String = AppLanguage.system.rawValue
    @AppStorage(PreferencesStore.PrefKey.primaryCurrencyCode) private var primaryCurrencyCodeRaw: String = "BRL"
    @State private var showSignOutConfirm = false

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
                        router.present(.subscriptionBenefits)
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
                    router.push(.onboardingTutorial, in: .settings)
                } label: {
                    Label("Tutorial rápido", systemImage: "questionmark.circle")
                }
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

                Picker("Idioma do app", selection: appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.label).tag(language)
                    }
                }
            } header: {
                Text("Aparência")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Personalize o visual do app.")
                    Text("O idioma pode exigir reiniciar o app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                HStack {
                    Text("Versão do app")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(.secondary)
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
        .navigationTitle("Ajustes")
        .alert("Sair da conta?", isPresented: $showSignOutConfirm) {
            Button("Cancelar", role: .cancel) {}
            Button("Sair", role: .destructive) {
                authViewModel.signOut()
            }
        } message: {
            Text("Você precisará fazer login novamente para acessar o app.")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
        .environmentObject(SubscriptionManager.shared)
        .environmentObject(AppRouter())
}
