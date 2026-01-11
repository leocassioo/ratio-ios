//
//  NotificationRouteHandler.swift
//  Ratio
//
//  Created by Codex on 08/01/26.
//

import Foundation

final class NotificationRouteHandler {
    static let shared = NotificationRouteHandler()

    private var pendingPayload: NotificationRoutePayload?

    private init() {}

    func handle(userInfo: [AnyHashable: Any]) {
        guard let payload = NotificationRoutePayload(userInfo: userInfo) else { return }
        pendingPayload = payload
        NotificationCenter.default.post(name: .notificationRouteDidReceive, object: payload)
    }

    func consumePendingPayload() -> NotificationRoutePayload? {
        let payload = pendingPayload
        pendingPayload = nil
        return payload
    }
}
