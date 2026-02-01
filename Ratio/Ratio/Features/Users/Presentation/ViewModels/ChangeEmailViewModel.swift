//
//  ChangeEmailViewModel.swift
//  Ratio
//
//  Created by Codex on 20/02/26.
//

import FirebaseAuth
import Foundation
import Combine

@MainActor
final class ChangeEmailViewModel: ObservableObject {
    @Published var newEmail: String = ""
    @Published var currentPassword: String = ""
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var successMessage: String?
    private let analytics: AnalyticsService

    init(analytics: AnalyticsService = .shared) {
        self.analytics = analytics
    }

    func updateEmail() {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "Usuário não autenticado."
            return
        }
        let trimmedEmail = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            errorMessage = "Informe o novo email."
            return
        }
        guard !currentPassword.isEmpty else {
            errorMessage = "Informe sua senha atual."
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                guard let currentEmail = user.email else {
                    throw NSError(domain: "ChangeEmail", code: 0, userInfo: [
                        NSLocalizedDescriptionKey: "Email atual indisponível."
                    ])
                }
                let credential = EmailAuthProvider.credential(withEmail: currentEmail, password: currentPassword)
                try await user.reauthenticate(with: credential)
                try await user.sendEmailVerification(beforeUpdatingEmail: trimmedEmail)
                successMessage = "Enviamos um link de confirmação. Faça login novamente após confirmar."
                analytics.track(.settings_change_email_success)
                currentPassword = ""
                PreferencesStore.shared.setPendingEmailChangeNotice(true)
                try Auth.auth().signOut()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
