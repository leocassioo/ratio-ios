//
//  NotificationHistoryItem.swift
//  Ratio
//
//  Created by Codex on 24/02/26.
//

import Foundation

struct NotificationHistoryItem: Identifiable {
    let id: String
    let title: String
    let message: String
    let date: Date
    let route: NotificationRoute
    let isRead: Bool
}
