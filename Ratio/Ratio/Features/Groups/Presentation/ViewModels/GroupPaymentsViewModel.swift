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

    private let store: GroupPaymentsStore

    init(store: GroupPaymentsStore? = nil) {
        self.store = store ?? GroupPaymentsStore()
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

    private func prepareReceiptData(_ data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let maxDimension: CGFloat = 1600
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
