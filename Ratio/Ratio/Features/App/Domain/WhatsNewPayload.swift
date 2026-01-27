//
//  WhatsNewPayload.swift
//  Ratio
//
//  Created by Codex on 27/01/26.
//

import Foundation

struct WhatsNewPayload: Decodable {
    let version: String
    let minVersion: String?
    let appStoreUrl: String?
    let slides: [String: [WhatsNewSlide]]

    struct WhatsNewSlide: Decodable, Identifiable {
        let id: UUID
        let title: String
        let description: String
        let imageUrl: String

        init(title: String, description: String, imageUrl: String) {
            self.id = UUID()
            self.title = title
            self.description = description
            self.imageUrl = imageUrl
        }

        private enum CodingKeys: String, CodingKey {
            case title
            case description
            case imageUrl
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let title = try container.decode(String.self, forKey: .title)
            let description = try container.decode(String.self, forKey: .description)
            let imageUrl = try container.decode(String.self, forKey: .imageUrl)
            self.init(title: title, description: description, imageUrl: imageUrl)
        }
    }

    func slides(for locale: Locale) -> [WhatsNewSlide] {
        let normalized = locale.identifier.replacingOccurrences(of: "_", with: "-")
        if let slides = slides[normalized], !slides.isEmpty {
            return slides
        }
        if let language = locale.languageCode {
            if let slides = slides[language], !slides.isEmpty {
                return slides
            }
            if language == "pt" {
                if let slides = slides["pt-BR"], !slides.isEmpty {
                    return slides
                }
                if let slides = slides["pt-PT"], !slides.isEmpty {
                    return slides
                }
            }
            if language == "zh", let slides = slides["zh-Hans"], !slides.isEmpty {
                return slides
            }
        }
        if let slides = slides["en"], !slides.isEmpty {
            return slides
        }
        return slides.values.first ?? []
    }

    var appStoreURL: URL? {
        guard let appStoreUrl, let url = URL(string: appStoreUrl) else { return nil }
        return url
    }
}

struct AppVersion {
    static var current: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static func isLower(_ lhs: String, than rhs: String) -> Bool {
        compare(lhs, rhs) == .orderedAscending
    }

    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let leftParts = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let rightParts = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let maxCount = max(leftParts.count, rightParts.count)

        for index in 0..<maxCount {
            let left = index < leftParts.count ? leftParts[index] : 0
            let right = index < rightParts.count ? rightParts[index] : 0
            if left < right { return .orderedAscending }
            if left > right { return .orderedDescending }
        }
        return .orderedSame
    }
}
