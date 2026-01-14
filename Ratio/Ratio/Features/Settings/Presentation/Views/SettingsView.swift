//
//  SettingsView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @AppStorage("appLanguage") private var appLanguageRaw: String = AppLanguage.system.rawValue
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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let user = authViewModel.user {
                        NavigationLink {
                            EditProfileView(user: user)
                        } label: {
                            Label("Perfil", systemImage: "person.crop.circle")
                        }
                    }
                } header: {
                    Text("Conta")
                }

                Section {
                    NavigationLink {
                        BillingHistoryView()
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
}

#Preview {
    SettingsView()
}
