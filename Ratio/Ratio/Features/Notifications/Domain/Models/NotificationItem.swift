//
//  NotificationItem.swift
//  Ratio
//
//  Created by Codex on 24/02/26.
//

import Foundation

struct NotificationItem: Identifiable {
    let id: String
    let title: String
    let body: String
    let route: NotificationRoute
    let type: String
    let data: [String: String]
    let isRead: Bool
    let createdAt: Date
}
