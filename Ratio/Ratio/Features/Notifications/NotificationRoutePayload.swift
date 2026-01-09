//
//  NotificationRoutePayload.swift
//  Ratio
//
//  Created by Codex on 08/01/26.
//

import Foundation

struct NotificationRoutePayload {
    let route: NotificationRoute

    init?(userInfo: [AnyHashable: Any]) {
        guard let routeValue = userInfo["route"] as? String,
              let route = NotificationRoute(rawValue: routeValue) else {
            return nil
        }
        self.route = route
    }
}
