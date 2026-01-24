//
//  GroupPaymentsViewModel.swift
//  Ratio
//
//  Created by Codex on 08/01/26.
//

import Foundation
import UIKit
import Combine

@MainActor
final class GroupPaymentsViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var userPixKey: String?

    private let store: GroupPaymentsStore
    private let usersStore: UsersStore

    init(
        store: GroupPaymentsStore? = nil,
        usersStore: UsersStore = UsersStore()
    ) {
        self.store = store ?? GroupPaymentsStore()
        self.usersStore = usersStore
    }

    func submitPayment(groupId: String, memberId: String, receiptData: Data?) async {
        isLoading = true
        errorMessage = nil

        do {
            var receiptURL: String?
            if let receiptData {
                let prepared = prepareReceiptData(receiptData)
                receiptURL = try await store.uploadReceipt(groupId: groupId, memberId: memberId, data: prepared)
            }
            try await store.submitPayment(groupId: groupId, memberId: memberId, receiptURL: receiptURL)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func approvePayment(groupId: String, memberId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            try await store.approvePayment(groupId: groupId, memberId: memberId)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func fetchUserPixKey(userId: String) async {
        do {
            if let profile = try await usersStore.fetchUserProfile(userId: userId) {
                userPixKey = profile.pixKey
            }
        } catch {
            print("Error fetching user profile: \(error)")
        }
    }

    private func prepareReceiptData(_ data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let maxDimension: CGFloat = 1024
        let resized = resizeImage(image, maxDimension: maxDimension)
        return compressImageData(resized, maxBytes: 100_000) ?? data
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

    private func compressImageData(_ image: UIImage, maxBytes: Int) -> Data? {
        var quality: CGFloat = 0.45
        var data = image.jpegData(compressionQuality: quality)
        while let current = data, current.count > maxBytes, quality > 0.3 {
            quality -= 0.08
            data = image.jpegData(compressionQuality: quality)
        }
        return data
    }
}
