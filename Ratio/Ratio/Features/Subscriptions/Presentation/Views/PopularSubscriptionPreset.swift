//
//  PopularSubscriptionPreset.swift
//  Ratio
//
//  Created by Codex on 31/01/26.
//

import SwiftUI

struct PopularSubscriptionPreset: Identifiable {
    let id: String
    let name: String
    let category: SubscriptionCategory
    let period: SubscriptionPeriod
    let currencyCode: String
    let suggestedAmount: Double?
    let tint: Color
    let assetName: String?
    let initials: String

    init(
        name: String,
        category: SubscriptionCategory,
        period: SubscriptionPeriod = .monthly,
        currencyCode: String = "BRL",
        suggestedAmount: Double? = nil,
        tint: Color,
        assetName: String? = nil
    ) {
        self.id = name.lowercased()
        self.name = name
        self.category = category
        self.period = period
        self.currencyCode = currencyCode
        self.suggestedAmount = suggestedAmount
        self.tint = tint
        self.assetName = assetName
        self.initials = PopularSubscriptionPreset.makeInitials(from: name)
    }

    static let defaultPresets: [PopularSubscriptionPreset] = [
        PopularSubscriptionPreset(name: "Netflix", category: .streaming, tint: .red, assetName: "netflix"),
        PopularSubscriptionPreset(name: "Prime Video", category: .streaming, tint: .blue, assetName: "prime video"),
        PopularSubscriptionPreset(name: "Spotify", category: .music, tint: .green, assetName: "spotify"),
        PopularSubscriptionPreset(name: "Amazon Prime", category: .streaming, tint: .blue, assetName: "amazon prime"),
        PopularSubscriptionPreset(name: "Disney+", category: .streaming, tint: .purple, assetName: "disney+"),
        PopularSubscriptionPreset(name: "MAX", category: .streaming, tint: .indigo, assetName: "max"),
        PopularSubscriptionPreset(name: "YouTube Premium", category: .music, tint: .red, assetName: "youtube premium"),
        PopularSubscriptionPreset(name: "Apple Music", category: .music, tint: .pink, assetName: "apple music"),
        PopularSubscriptionPreset(name: "Apple One", category: .software, tint: .gray, assetName: "apple one"),
        PopularSubscriptionPreset(name: "iCloud+", category: .software, tint: .cyan, assetName: "icloud+"),
        PopularSubscriptionPreset(name: "Google One", category: .software, tint: .yellow, assetName: "google one"),
        PopularSubscriptionPreset(name: "Deezer", category: .music, tint: .pink, assetName: "deezer"),
        PopularSubscriptionPreset(name: "Globoplay", category: .streaming, tint: .orange, assetName: "globoplay"),
        PopularSubscriptionPreset(name: "Paramount+", category: .streaming, tint: .blue, assetName: "paramount+"),
        PopularSubscriptionPreset(name: "Star+", category: .streaming, tint: .orange, assetName: "star+"),
        PopularSubscriptionPreset(name: "ChatGPT", category: .software, tint: .green, assetName: "chatgpt"),
        PopularSubscriptionPreset(name: "Microsoft 365", category: .software, tint: .blue, assetName: "microsoft 365"),
        PopularSubscriptionPreset(name: "Adobe CC", category: .software, tint: .red, assetName: "adobe cc"),
        PopularSubscriptionPreset(name: "Canva Pro", category: .software, tint: .purple, assetName: "canva pro")
    ]

    private static func makeInitials(from name: String) -> String {
        let parts = name
            .replacingOccurrences(of: "+", with: "")
            .split(separator: " ")
            .map(String.init)
        if let first = parts.first, parts.count == 1 {
            return String(first.prefix(1)).uppercased()
        }
        let first = parts.first?.prefix(1) ?? ""
        let second = parts.dropFirst().first?.prefix(1) ?? ""
        let initials = "\(first)\(second)".uppercased()
        return initials.isEmpty ? "?" : initials
    }
}
