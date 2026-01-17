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
    @Published var pixKey: String
    @Published var selectedPhoto: PhotosPickerItem?
    @Published var profileImageData: Data?
    @Published private(set) var remotePhotoURL: URL?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var saveSuccess = false

    private let user: User
    private let usersStore: UsersStore
    private let groupsStore: GroupsStore

    init(user: User, usersStore: UsersStore? = nil, groupsStore: GroupsStore? = nil) {
        self.user = user
        self.usersStore = usersStore ?? UsersStore()
        self.groupsStore = groupsStore ?? GroupsStore()
        self.name = user.displayName ?? ""
        self.email = user.email ?? ""
        self.phoneNumber = ""
        self.pixKey = ""
        self.remotePhotoURL = user.photoURL
    }

    func loadProfile() {
        Task {
            do {
                if let profile = try await usersStore.fetchUserProfile(userId: user.uid) {
                    name = profile.name ?? name
                    email = profile.email ?? email
                    phoneNumber = profile.phoneNumber ?? phoneNumber
                    pixKey = profile.pixKey ?? pixKey
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
                await MainActor.run {
                    saveChanges()
                }
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
                    photoURL: updatedPhotoURL?.absoluteString,
                    pixKey: pixKey
                )
                try await groupsStore.updateMemberPhoto(
                    userId: user.uid,
                    photoURL: updatedPhotoURL?.absoluteString
                )

                remotePhotoURL = updatedPhotoURL
                saveSuccess = true
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run {
                        self?.saveSuccess = false
                    }
                }
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
