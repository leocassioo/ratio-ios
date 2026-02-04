//
//  PopularSubscriptionPresetView.swift
//  Ratio
//
//  Created by Codex on 31/01/26.
//

import SwiftUI

struct PopularSubscriptionPresetView: View {
    let preset: PopularSubscriptionPreset
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            let size: CGFloat = 52
            let ringWidth: CGFloat = 2.5
            let ringGradient = LinearGradient(
                colors: ringColors(for: preset),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ZStack {
                if let assetName = preset.assetName, UIImage(named: assetName) != nil {
                    Image(assetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else {
                    Text(preset.initials)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: size, height: size)
                        .background(Circle().fill(preset.tint))
                }

                Circle()
                    .stroke(ringGradient, lineWidth: ringWidth)
                    .frame(width: size, height: size)
            }

            Text(preset.name)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 72, height: 28, alignment: .top)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Selecionar \(preset.name)"))
    }

    private func ringColors(for preset: PopularSubscriptionPreset) -> [Color] {
        return [Color(red: 0.36, green: 0.74, blue: 1.0), Color(red: 0.64, green: 0.42, blue: 0.94)]
    }
}

#Preview {
    PopularSubscriptionPresetView(preset: PopularSubscriptionPreset(name: "Netflix", category: .streaming, tint: .red))
}
