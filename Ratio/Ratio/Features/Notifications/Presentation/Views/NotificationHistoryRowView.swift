//
//  NotificationHistoryRowView.swift
//  Ratio
//
//  Created by Codex on 24/02/26.
//

import SwiftUI

struct NotificationHistoryRowView: View {
    let item: NotificationItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(item.isRead ? Color.clear : Color.accentColor)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(item.body)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(relativeMinuteLabel(for: item.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }

    private func relativeMinuteLabel(for date: Date) -> String {
        let minutes = max(0, Int(Date().timeIntervalSince(date) / 60))
        if minutes == 0 {
            return "agora"
        }
        if minutes < 60 {
            return "\(minutes) min"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: date)
    }
}
