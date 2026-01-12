//
//  EditProfileViewModel.swift
//  Ratio
//
//  Created by Codex on 15/02/26.
//

import FirebaseAuth
import FirebaseStorage
import PhotosUI
import SwiftUI
import UIKit
import Combine

@MainActor
final class EditProfileViewModel: ObservableObject {
    @Published var name: String
    @Published var email: String
    @Published var phoneNumber: String
    @Published var selectedPhoto: PhotosPickerItem?
    @Published var profileImageData: Data?
    @Published private(set) var remotePhotoURL: URL?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var saveSuccess = false

    private let user: User
    private let usersStore: UsersStore

    init(user: User, usersStore: UsersStore = UsersStore()) {
        self.user = user
        self.usersStore = usersStore
        self.name = user.displayName ?? ""
        self.email = user.email ?? ""
        self.phoneNumber = ""
        self.remotePhotoURL = user.photoURL
    }

    func loadProfile() {
        Task {
            do {
                if let profile = try await usersStore.fetchUserProfile(userId: user.uid) {
                    name = profile.name ?? name
                    email = profile.email ?? email
                    phoneNumber = profile.phoneNumber ?? phoneNumber
                    if let photo = profile.photoURL, let url = URL(string: photo) {
                        remotePhotoURL = url
                    }
                }
            } catch {
                errorMessage = "Não foi possível carregar o perfil."
            }
        }
    }

    func handleSelectedPhotoChange() {
        guard let selectedPhoto else { return }
        Task {
            if let data = try? await selectedPhoto.loadTransferable(type: Data.self) {
                profileImageData = data
            }
        }
    }

    func saveChanges() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Informe seu nome para salvar."
            return
        }

        isLoading = true
        errorMessage = nil
        saveSuccess = false

        Task {
            do {
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                var updatedPhotoURL = remotePhotoURL

                if let profileImageData {
                    let uploadData = prepareProfilePhotoData(profileImageData)
                    let uploadedURL = try await uploadProfilePhoto(userId: user.uid, data: uploadData)
                    updatedPhotoURL = uploadedURL
                }

                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = trimmedName
                changeRequest.photoURL = updatedPhotoURL
                try await changeRequest.commitChanges()

                try await usersStore.updateUserProfile(
                    userId: user.uid,
                    name: trimmedName,
                    email: email,
                    phoneNumber: phoneNumber,
                    photoURL: updatedPhotoURL?.absoluteString
                )

                remotePhotoURL = updatedPhotoURL
                saveSuccess = true
            } catch {
                errorMessage = "Não foi possível salvar o perfil."
            }

            isLoading = false
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
