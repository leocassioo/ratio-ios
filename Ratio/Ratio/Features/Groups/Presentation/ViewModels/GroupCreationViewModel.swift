//
//  GroupCreationViewModel.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import Combine
import FirebaseFirestore
import Foundation

@MainActor
final class GroupCreationViewModel: ObservableObject {
    @Published private(set) var subscriptions: [SubscriptionItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let store: SubscriptionsStore
    private var listener: ListenerRegistration?
    private let ownerId: String

    init(ownerId: String, store: SubscriptionsStore? = nil) {
        self.ownerId = ownerId
        self.store = store ?? SubscriptionsStore()
    }

    deinit {
        listener?.remove()
    }

    func startListening() {
        listener?.remove()
        isLoading = true
        errorMessage = nil

        listener = store.listenSubscriptions(for: ownerId) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let items):
                    self?.subscriptions = items
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
