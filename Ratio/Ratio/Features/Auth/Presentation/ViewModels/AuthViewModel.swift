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

    private var handle: AuthStateDidChangeListenerHandle?
    private let usersStore = UsersStore()

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
        }
    }

    deinit {
        if let handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func signIn(email: String, password: String) {
        authenticate {
            try await Auth.auth().signIn(withEmail: email, password: password)
        }
    }

    func signUp(email: String, password: String, displayName: String, phoneNumber: String, photoData: Data?) {
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
            try await self.usersStore.upsertUser(
                userId: result.user.uid,
                name: profileName,
                email: profileEmail,
                phoneNumber: phoneNumber,
                photoURL: profilePhoto
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
        let maxDimension: CGFloat = 512
        let resized = resizeImage(image, maxDimension: maxDimension)
        return resized.jpegData(compressionQuality: 0.8) ?? data
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
