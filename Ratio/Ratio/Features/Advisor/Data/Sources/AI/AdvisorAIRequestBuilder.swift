//
//  AdvisorAIRequestBuilder.swift
//  Ratio
//
//  Created by Codex on 15/02/26.
//

import Foundation

struct AdvisorAIRequestBuilder {
    let apiKey: String
    let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func makeRequest(_ endpoint: AdvisorAIEndpoint, body: [String: Any]) throws -> URLRequest {
        guard let url = endpoint.url else { throw AdvisorAIError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        return request
    }

    func perform(_ request: URLRequest) async throws -> AdvisorAIResponse {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw AdvisorAIError.invalidResponse
        }
        guard let response = parseResponse(from: data), !response.content.isEmpty else {
            throw AdvisorAIError.emptyResponse
        }
        return response
    }

    private func parseResponse(from data: Data) -> AdvisorAIResponse? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            return nil
        }
        let usage = json["usage"] as? [String: Any]
        let totalTokens = usage?["total_tokens"] as? Int
        return AdvisorAIResponse(content: content, totalTokens: totalTokens)
    }
}

struct AdvisorAIResponse {
    let content: String
    let totalTokens: Int?
}
