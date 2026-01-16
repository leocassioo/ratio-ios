//
//  AuthViewModel.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import FirebaseAuth
import FirebaseStorage
import Foundation
import UIKit
import Combine

final class AuthViewModel: ObservableObject {
    @Published private(set) var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var passwordResetSent = false
    @Published private(set) var userPixKey: String?

    private var handle: AuthStateDidChangeListenerHandle?
    private let usersStore = UsersStore()

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            if let user {
                Task {
                    await self?.fetchProfile(userId: user.uid)
                }
            } else {
                self?.userPixKey = nil
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
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = error.localizedDescription
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
                _ = try await operation()
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
}
