//
//  NotificationMapper.swift
//  Ratio
//
//  Created by Codex on 24/02/26.
//

import FirebaseFirestore
import Foundation

enum NotificationMapper {
    static func item(from document: QueryDocumentSnapshot) -> NotificationItem? {
        let data = document.data()
        guard let title = data["title"] as? String,
              let body = data["body"] as? String,
              let routeRaw = data["route"] as? String,
              let route = NotificationRoute(rawValue: routeRaw),
              let type = data["type"] as? String else {
            return nil
        }
        let isRead = data["isRead"] as? Bool ?? false
        let payload = data["data"] as? [String: String] ?? [:]
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        return NotificationItem(
            id: document.documentID,
            title: title,
            body: body,
            route: route,
            type: type,
            data: payload,
            isRead: isRead,
            createdAt: createdAt
        )
    }
}
