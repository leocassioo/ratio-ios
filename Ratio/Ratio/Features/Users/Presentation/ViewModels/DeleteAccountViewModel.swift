//
//  DeleteAccountViewModel.swift
//  Ratio
//
//  Created by Codex on 27/01/26.
//

import AuthenticationServices
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import Foundation
import UIKit
import Combine

@MainActor
final class DeleteAccountViewModel: ObservableObject {
    enum ReauthProvider {
        case password
        case apple
        case google
    }

    @Published var password: String = ""
    @Published var hasConfirmed = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private(set) var supportsPassword = false
    private(set) var supportsApple = false
    private(set) var supportsGoogle = false
    private let analytics: AnalyticsService

    init(analytics: AnalyticsService = .shared) {
        self.analytics = analytics
        refreshProviders()
    }

    func refreshProviders() {
        let providers = Auth.auth().currentUser?.providerData.map { $0.providerID } ?? []
        supportsPassword = providers.contains("password")
        supportsApple = providers.contains("apple.com")
        supportsGoogle = providers.contains("google.com")
        if supportsPassword == false && supportsApple == false && supportsGoogle == false {
            supportsPassword = true
        }
    }

    func deleteWithPassword() {
        guard hasConfirmed else { return }
        guard let user = Auth.auth().currentUser else {
            errorMessage = "Usuário não autenticado."
            return
        }
        guard let email = user.email else {
            errorMessage = "Email atual indisponível."
            return
        }
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPassword.isEmpty else {
            errorMessage = "Informe sua senha atual."
            return
        }

        isLoading = true
        errorMessage = nil
        analytics.track(.settings_delete_account_start)

        Task {
            do {
                let credential = EmailAuthProvider.credential(withEmail: email, password: trimmedPassword)
                try await user.reauthenticate(with: credential)
                try await user.delete()
                try? Auth.auth().signOut()
                analytics.track(.settings_delete_account_success)
            } catch {
                errorMessage = error.localizedDescription
                analytics.track(.settings_delete_account_error, parameters: ["reason": String(describing: error)])
            }
            isLoading = false
        }
    }

    func deleteWithGoogle(presenting: UIViewController) {
        guard hasConfirmed else { return }
        guard let user = Auth.auth().currentUser else {
            errorMessage = "Usuário não autenticado."
            return
        }

        isLoading = true
        errorMessage = nil
        analytics.track(.settings_delete_account_start)

        Task {
            do {
                guard let clientID = FirebaseApp.app()?.options.clientID else {
                    throw NSError(domain: "DeleteAccount", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Configuração do Google ausente."
                    ])
                }
                let config = GIDConfiguration(clientID: clientID)
                GIDSignIn.sharedInstance.configuration = config

                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
                guard let idToken = result.user.idToken?.tokenString else {
                    throw NSError(domain: "DeleteAccount", code: -2, userInfo: [
                        NSLocalizedDescriptionKey: "Token do Google inválido."
                    ])
                }
                let accessToken = result.user.accessToken.tokenString
                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
                try await user.reauthenticate(with: credential)
                try await user.delete()
                try? Auth.auth().signOut()
                analytics.track(.settings_delete_account_success)
            } catch {
                errorMessage = error.localizedDescription
                analytics.track(.settings_delete_account_error, parameters: ["reason": String(describing: error)])
            }
            isLoading = false
        }
    }

    func deleteWithApple(authorization: ASAuthorization, rawNonce: String) {
        guard hasConfirmed else { return }
        guard let user = Auth.auth().currentUser else {
            errorMessage = "Usuário não autenticado."
            return
        }

        isLoading = true
        errorMessage = nil
        analytics.track(.settings_delete_account_start)

        Task {
            do {
                guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                    throw NSError(domain: "DeleteAccount", code: -3, userInfo: [
                        NSLocalizedDescriptionKey: "Credencial da Apple inválida."
                    ])
                }
                guard let tokenData = appleCredential.identityToken,
                      let idTokenString = String(data: tokenData, encoding: .utf8) else {
                    throw NSError(domain: "DeleteAccount", code: -4, userInfo: [
                        NSLocalizedDescriptionKey: "Token da Apple inválido."
                    ])
                }

                let credential = OAuthProvider.credential(
                    providerID: .apple,
                    idToken: idTokenString,
                    rawNonce: rawNonce
                )
                try await user.reauthenticate(with: credential)
                try await user.delete()
                try? Auth.auth().signOut()
                analytics.track(.settings_delete_account_success)
            } catch {
                errorMessage = error.localizedDescription
                analytics.track(.settings_delete_account_error, parameters: ["reason": String(describing: error)])
            }
            isLoading = false
        }
    }
}
