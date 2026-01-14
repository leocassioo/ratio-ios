//
//  SmartAdvisorViewModel.swift
//  Ratio
//
//  Created by Codex on 15/02/26.
//

import FirebaseFirestore
import Foundation
import Combine

@MainActor
final class SmartAdvisorViewModel: ObservableObject {
    @Published private(set) var insights: [AdvisorInsight] = []
    @Published private(set) var stats: [AdvisorStat] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasRequestedAnalysis = false

    private let subscriptionsStore: SubscriptionsStore
    private let groupsStore: GroupsStore
    private let provider: AdvisorAIProvider
    private var subscriptions: [SubscriptionItem] = []
    private var groups: [SharedGroup] = []
    private var subscriptionsListener: ListenerRegistration?
    private var groupsListener: ListenerRegistration?
    private var userId: String?
    private var hasLoadedOnce = false
    private var isListening = false

    init(
        subscriptionsStore: SubscriptionsStore = SubscriptionsStore(),
        groupsStore: GroupsStore = GroupsStore(),
        provider: AdvisorAIProvider? = nil
    ) {
        self.subscriptionsStore = subscriptionsStore
        self.groupsStore = groupsStore

        if let provider {
            self.provider = provider
        } else {
            let remoteKey = RemoteConfigService.shared.openAiApiKey
            if let key = remoteKey?.trimmingCharacters(in: .whitespacesAndNewlines),
               !key.isEmpty {
                self.provider = OpenAIChatAdvisorProvider(apiKey: key)
            } else {
                self.provider = NoopAdvisorAIProvider()
            }
        }
    }

    deinit {
        subscriptionsListener?.remove()
        groupsListener?.remove()
    }

    func start(userId: String) {
        if isListening, self.userId == userId {
            return
        }
        self.userId = userId
        subscriptionsListener?.remove()
        groupsListener?.remove()
        isListening = true

        subscriptionsListener = subscriptionsStore.listenSubscriptions(for: userId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let items):
                    self?.subscriptions = items
                    self?.refreshIfNeeded()
                case .failure:
                    self?.subscriptions = []
                }
            }
        }

        groupsListener = groupsStore.listenGroups(for: userId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let groups):
                    self?.groups = groups
                    self?.refreshIfNeeded()
                case .failure:
                    self?.groups = []
                }
            }
        }
    }

    func stop() {
        subscriptionsListener?.remove()
        groupsListener?.remove()
        subscriptionsListener = nil
        groupsListener = nil
        isListening = false
    }

    func refreshInsights() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        hasRequestedAnalysis = true

        let remoteKey = RemoteConfigService.shared.openAiApiKey
        if remoteKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            errorMessage = "Análises indisponíveis no momento. Tente novamente mais tarde."
            isLoading = false
            return
        }

        let context = buildContext()

        Task {
            do {
                let result = try await provider.generateInsights(context: context)
                insights = result.insights
                stats = result.stats
            } catch {
                errorMessage = "Não foi possível gerar insights agora."
            }
            isLoading = false
            hasLoadedOnce = true
        }
    }

    private func refreshIfNeeded() {
        guard hasRequestedAnalysis else { return }
        guard !hasLoadedOnce, !subscriptions.isEmpty || !groups.isEmpty else { return }
        refreshInsights()
    }

    private func buildContext() -> String {
        let dateFormatter = ISO8601DateFormatter()
        let subscriptionPayloads: [[String: Any]] = subscriptions.map { item in
            [
                "name": item.name,
                "amount": item.amount,
                "currencyCode": item.currencyCode,
                "period": item.period.rawValue,
                "category": item.category.rawValue,
                "nextBillingDate": dateFormatter.string(from: item.nextBillingDate)
            ]
        }

        let groupPayloads: [[String: Any]] = groups.map { group in
            [
                "name": group.name,
                "totalAmount": group.totalAmount,
                "currencyCode": group.currencyCode,
                "memberCount": group.members.count,
                "subscriptionName": group.subscriptionName as Any,
                "chargeNextBillingDate": group.chargeNextBillingDate.map { dateFormatter.string(from: $0) } as Any
            ]
        }

        let payload: [String: Any] = [
            "generatedAt": dateFormatter.string(from: Date()),
            "subscriptions": subscriptionPayloads,
            "groups": groupPayloads
        ]

        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
           let json = String(data: data, encoding: .utf8) {
            return json
        }

        return "{}"
    }
}
