//
//  AuthViewModel.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import FirebaseAuth
import FirebaseCore
import FirebaseMessaging
import FirebaseStorage
import AuthenticationServices
import GoogleSignIn
import Foundation
import UIKit
import Combine

final class AuthViewModel: ObservableObject {
    @Published private(set) var user: User?
    @Published private(set) var isAuthReady = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var passwordResetSent = false
    @Published private(set) var userPixKey: String?

    private var handle: AuthStateDidChangeListenerHandle?
    private let usersStore = UsersStore()
    private let preferencesStore = PreferencesStore.shared

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            DispatchQueue.main.async {
                self?.isAuthReady = true
            }
            if let user {
                Task {
                    await self?.fetchProfile(userId: user.uid)
                    await self?.handleAuthChange(currentUserId: user.uid)
                }
            } else {
                self?.userPixKey = nil
                Task {
                    await self?.handleAuthChange(currentUserId: nil)
                }
            }
        }
    }

    deinit {
        if let handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func signIn(email: String, password: String) {
        authenticate {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            try await self.usersStore.updateUserProfile(
                userId: result.user.uid,
                name: result.user.displayName,
                email: result.user.email,
                photoURL: result.user.photoURL?.absoluteString,
                pixKey: nil
            )
            return result
        }
    }

    func signUp(email: String, password: String, displayName: String, phoneNumber: String, pixKey: String, photoData: Data?) {
        authenticate {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let changeRequest = result.user.createProfileChangeRequest()
            if !trimmedName.isEmpty {
                changeRequest.displayName = trimmedName
            }
            if let photoData {
                let uploadData = self.prepareProfilePhotoData(photoData)
                let photoURL = try await self.uploadProfilePhoto(userId: result.user.uid, data: uploadData)
                changeRequest.photoURL = photoURL
            }
            if changeRequest.displayName != nil || changeRequest.photoURL != nil {
                try await changeRequest.commitChanges()
            }
            let profileName = trimmedName.isEmpty ? (result.user.displayName ?? "") : trimmedName
            let profileEmail = result.user.email ?? email
            let profilePhoto = changeRequest.photoURL?.absoluteString ?? result.user.photoURL?.absoluteString
            let trimmedPixKey = pixKey.trimmingCharacters(in: .whitespacesAndNewlines)
            try await self.usersStore.upsertUser(
                userId: result.user.uid,
                name: profileName,
                email: profileEmail,
                phoneNumber: phoneNumber,
                photoURL: profilePhoto,
                pixKey: trimmedPixKey.isEmpty ? nil : trimmedPixKey
            )
            return result
        }
    }

    func signOut() {
        Task {
            await handleAuthChange(currentUserId: nil, beforeSignOut: true)
            await deleteCurrentFCMToken()
            preferencesStore.setLastFcmToken(nil)
            do {
                try Auth.auth().signOut()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func signInWithGoogle(presenting: UIViewController) {
        errorMessage = nil
        isLoading = true

        Task { [weak self] in
            do {
                guard let clientID = FirebaseApp.app()?.options.clientID else {
                    throw NSError(domain: "Auth", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Configuração do Google ausente."
                    ])
                }
                let config = GIDConfiguration(clientID: clientID)
                GIDSignIn.sharedInstance.configuration = config

                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
                guard let idToken = result.user.idToken?.tokenString else {
                    throw NSError(domain: "Auth", code: -2, userInfo: [
                        NSLocalizedDescriptionKey: "Token do Google inválido."
                    ])
                }
                let accessToken = result.user.accessToken.tokenString
                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
                let authResult = try await Auth.auth().signIn(with: credential)

                try await self?.usersStore.updateUserProfile(
                    userId: authResult.user.uid,
                    name: authResult.user.displayName ?? result.user.profile?.name,
                    email: authResult.user.email,
                    photoURL: authResult.user.photoURL?.absoluteString,
                    pixKey: nil
                )
                await MainActor.run {
                    self?.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self?.isLoading = false
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func signInWithApple(authorization: ASAuthorization, rawNonce: String) {
        errorMessage = nil
        isLoading = true

        Task { [weak self] in
            do {
                guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                    throw NSError(domain: "Auth", code: -3, userInfo: [
                        NSLocalizedDescriptionKey: "Credencial da Apple inválida."
                    ])
                }
                guard let tokenData = appleIDCredential.identityToken,
                      let idTokenString = String(data: tokenData, encoding: .utf8) else {
                    throw NSError(domain: "Auth", code: -4, userInfo: [
                        NSLocalizedDescriptionKey: "Token da Apple inválido."
                    ])
                }

                let credential = OAuthProvider.credential(
                    providerID: .apple,
                    idToken: idTokenString,
                    rawNonce: rawNonce
                )
                let authResult = try await Auth.auth().signIn(with: credential)

                if let fullName = appleIDCredential.fullName {
                    let formatter = PersonNameComponentsFormatter()
                    let name = formatter.string(from: fullName)
                    if !name.isEmpty {
                        let changeRequest = authResult.user.createProfileChangeRequest()
                        changeRequest.displayName = name
                        try await changeRequest.commitChanges()
                    }
                }

                try await self?.usersStore.updateUserProfile(
                    userId: authResult.user.uid,
                    name: authResult.user.displayName,
                    email: authResult.user.email,
                    photoURL: authResult.user.photoURL?.absoluteString,
                    pixKey: nil
                )

                await MainActor.run {
                    self?.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self?.isLoading = false
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func sendPasswordReset(email: String) {
        errorMessage = nil
        passwordResetSent = false
        isLoading = true

        Task { [weak self] in
            do {
                try await Auth.auth().sendPasswordReset(withEmail: email)
                await MainActor.run {
                    self?.isLoading = false
                    self?.passwordResetSent = true
                }
            } catch {
                await MainActor.run {
                    self?.isLoading = false
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func fetchProfile(userId: String) async {
        do {
            if let profile = try await usersStore.fetchUserProfile(userId: userId) {
                await MainActor.run {
                    self.userPixKey = profile.pixKey
                }
            }
        } catch {
            print("Error fetching profile: \(error)")
        }
    }

    private func authenticate(_ operation: @escaping () async throws -> AuthDataResult) {
        errorMessage = nil
        isLoading = true

        Task { [weak self] in
            do {
                let result = try await operation()
                await self?.handleAuthChange(currentUserId: result.user.uid)
                await MainActor.run {
                    self?.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self?.isLoading = false
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func uploadProfilePhoto(userId: String, data: Data) async throws -> URL {
        let ref = Storage.storage().reference().child("users/\(userId)/profile.jpg")
        _ = try await ref.putDataAsync(data)
        return try await ref.downloadURL()
    }

    private func prepareProfilePhotoData(_ data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let targetSize: CGFloat = 96
        let resized = resizeImageToSquare(image, dimension: targetSize)
        return resized.jpegData(compressionQuality: 0.6) ?? data
    }

    private func resizeImageToSquare(_ image: UIImage, dimension: CGFloat) -> UIImage {
        let size = image.size
        let scale = max(dimension / size.width, dimension / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: dimension, height: dimension))
        let origin = CGPoint(
            x: (dimension - newSize.width) / 2,
            y: (dimension - newSize.height) / 2
        )
        return renderer.image { _ in
            image.draw(in: CGRect(origin: origin, size: newSize))
        }
    }

    private func handleAuthChange(currentUserId: String?, beforeSignOut: Bool = false) async {
        let previousUserId = preferencesStore.lastAuthUserId()
        NotificationManager.shared.registerForRemoteNotificationsIfAuthorized()
        let token = await fetchFCMToken()

        if let previousUserId, previousUserId != currentUserId, let token {
            try? await usersStore.removeFCMToken(userId: previousUserId, token: token)
        }

        if let currentUserId, let token {
            try? await usersStore.updateFCMToken(userId: currentUserId, token: token)
            preferencesStore.setLastAuthUserId(currentUserId)
        } else if beforeSignOut {
            if let previousUserId, let token {
                try? await usersStore.removeFCMToken(userId: previousUserId, token: token)
            }
            preferencesStore.setLastAuthUserId(nil)
        } else {
            preferencesStore.setLastAuthUserId(nil)
        }
    }

    private func fetchFCMToken() async -> String? {
        await withCheckedContinuation { continuation in
            Messaging.messaging().token { token, _ in
                if let token {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(returning: self.preferencesStore.lastFcmToken())
                }
            }
        }
    }

    private func deleteCurrentFCMToken() async {
        await withCheckedContinuation { continuation in
            Messaging.messaging().deleteToken { _ in
                continuation.resume()
            }
        }
    }
}
