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

    func string(for key: FeatureFlagKey) -> String? {
        let value = remoteConfig.configValue(forKey: key.rawValue).stringValue
        return value.isEmpty == true ? nil : value
    }

    func int(for key: FeatureFlagKey) -> Int? {
        let number = remoteConfig.configValue(forKey: key.rawValue).numberValue
        return number == 0 ? nil : number.intValue
    }

    // Conveniências
    var reasoningEffortForAnalysis: String? { string(for: .reasoningEffortForAnalysis) }
    var maxCompletionTokensForAnalysis: Int? { int(for: .maxCompletionTokensForAnalysis) }
    var gptModel: String? { string(for: .gptModel) }
    var openAiApiKey: String? { string(for: .openAiApiKey) }
}

private extension RemoteConfigService {
    var defaultValues: [String: NSObject] {
        [
            FeatureFlagKey.reasoningEffortForAnalysis.rawValue: "low" as NSString,
            FeatureFlagKey.maxCompletionTokensForAnalysis.rawValue: 5000 as NSNumber,
            FeatureFlagKey.gptModel.rawValue: "gpt-5-nano-2025-08-07" as NSString,
            FeatureFlagKey.openAiApiKey.rawValue: "" as NSString
        ]
    }
}
