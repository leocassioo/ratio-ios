//
//  RemoteConfigService.swift
//  Ratio
//
//  Created by Codex on 15/02/26.
//

import Foundation
import FirebaseRemoteConfig

enum FeatureFlagKey: String {
    case reasoningEffortForAnalysis
    case maxCompletionTokensForAnalysis
    case gptModel
    case openAiApiKey
    case premiumBypass
    case premiumBypassEmails
    case whatsNewPayload = "whatsnew_payload"
    case popularSubscriptionsPayload = "popular_subscriptions_payload"
}

/// Wrapper para leitura de flags do Firebase Remote Config.
final class RemoteConfigService {
    static let shared = RemoteConfigService()
    private let remoteConfig: RemoteConfig

    private init(remoteConfig: RemoteConfig = RemoteConfig.remoteConfig()) {
        self.remoteConfig = remoteConfig
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3600
        #endif
        remoteConfig.configSettings = settings
        remoteConfig.setDefaults(defaultValues)
    }

    /// Busca e ativa os valores remotos.
    @MainActor
    func fetchAndActivate(completion: ((Result<Void, Error>) -> Void)? = nil) {
        remoteConfig.fetchAndActivate { _, error in
            if let error {
                completion?(.failure(error))
            } else {
                completion?(.success(()))
            }
        }
    }

    @MainActor
    func fetchAndActivate() async -> Bool {
        await withCheckedContinuation { continuation in
            remoteConfig.fetchAndActivate { _, error in
                continuation.resume(returning: error == nil)
            }
        }
    }

    func string(for key: FeatureFlagKey) -> String? {
        let value = remoteConfig.configValue(forKey: key.rawValue).stringValue
        return value.isEmpty == true ? nil : value
    }

    func int(for key: FeatureFlagKey) -> Int? {
        let number = remoteConfig.configValue(forKey: key.rawValue).numberValue
        return number == 0 ? nil : number.intValue
    }

    func bool(for key: FeatureFlagKey) -> Bool {
        remoteConfig.configValue(forKey: key.rawValue).boolValue
    }

    func data(for key: FeatureFlagKey) -> Data? {
        let stringValue = remoteConfig.configValue(forKey: key.rawValue).stringValue
        let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.data(using: .utf8)
    }

    // Conveniências
    var reasoningEffortForAnalysis: String? { string(for: .reasoningEffortForAnalysis) }
    var maxCompletionTokensForAnalysis: Int? { int(for: .maxCompletionTokensForAnalysis) }
    var gptModel: String? { string(for: .gptModel) }
    var openAiApiKey: String? { string(for: .openAiApiKey) }
    var premiumBypassEnabled: Bool { bool(for: .premiumBypass) }
    var premiumBypassEmails: [String] {
        guard let raw = string(for: .premiumBypassEmails) else { return [] }
        return raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }
    var whatsNewPayload: WhatsNewPayload? {
        guard let data = data(for: .whatsNewPayload) else { return nil }
        do {
            return try JSONDecoder().decode(WhatsNewPayload.self, from: data)
        } catch {
            print("RemoteConfig: failed to decode whatsNewPayload: \(error)")
            return nil
        }
    }

    var popularSubscriptionsPayload: PopularSubscriptionPayload? {
        guard let data = data(for: .popularSubscriptionsPayload) else { return nil }
        do {
            return try JSONDecoder().decode(PopularSubscriptionPayload.self, from: data)
        } catch {
            print("RemoteConfig: failed to decode popularSubscriptionsPayload: \(error)")
            return nil
        }
    }
}

private extension RemoteConfigService {
    var defaultValues: [String: NSObject] {
        [
            FeatureFlagKey.reasoningEffortForAnalysis.rawValue: "low" as NSString,
            FeatureFlagKey.maxCompletionTokensForAnalysis.rawValue: 5000 as NSNumber,
            FeatureFlagKey.gptModel.rawValue: "gpt-5-nano-2025-08-07" as NSString,
            FeatureFlagKey.openAiApiKey.rawValue: "" as NSString,
            FeatureFlagKey.premiumBypass.rawValue: false as NSNumber,
            FeatureFlagKey.premiumBypassEmails.rawValue: "" as NSString,
            FeatureFlagKey.whatsNewPayload.rawValue: defaultWhatsNewPayloadString,
            FeatureFlagKey.popularSubscriptionsPayload.rawValue: defaultPopularSubscriptionsPayloadString
        ]
    }

    var defaultWhatsNewPayloadString: NSString {
        guard let url = Bundle.main.url(forResource: "whatsnew_payload", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = String(data: data, encoding: .utf8) else {
            return "" as NSString
        }
        return raw as NSString
    }

    var defaultPopularSubscriptionsPayloadString: NSString {
        guard let url = Bundle.main.url(forResource: "popular_subscriptions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = String(data: data, encoding: .utf8) else {
            return "" as NSString
        }
        return raw as NSString
    }
}
