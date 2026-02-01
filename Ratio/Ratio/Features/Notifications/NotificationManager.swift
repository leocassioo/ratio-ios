//
//  NotificationManager.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import FirebaseAuth
import FirebaseMessaging
import Foundation
import UserNotifications
import UIKit

final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func configure() {
        UNUserNotificationCenter.current().delegate = NotificationCenterDelegate.shared
    }

    func registerForRemoteNotificationsIfAuthorized() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let authorizedStatuses: [UNAuthorizationStatus] = [.authorized, .provisional, .ephemeral]
            if authorizedStatuses.contains(settings.authorizationStatus) {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                DispatchQueue.main.async {
                    if granted {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                    completion?(granted)
                }
            }
    }

    func updateBadge(count: Int) {
        let safeCount = max(count, 0)
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(safeCount)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = safeCount
        }
    }
}

final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationCenterDelegate()
    private let analytics = AnalyticsService.shared

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if !shouldHandleNotification(userInfo: userInfo) {
            completionHandler()
            return
        }
        analytics.track(.notification_open, parameters: notificationParams(from: userInfo))
        NotificationRouteHandler.shared.handle(userInfo: userInfo)
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        if !shouldHandleNotification(userInfo: userInfo) {
            completionHandler([])
            return
        }
        analytics.track(.notification_received, parameters: notificationParams(from: userInfo))
        completionHandler([.banner, .list, .sound, .badge])
    }

    private func shouldHandleNotification(userInfo: [AnyHashable: Any]) -> Bool {
        guard let targetUserId = userInfo["targetUserId"] as? String else {
            return true
        }
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return false
        }
        return targetUserId == currentUserId
    }

    private func notificationParams(from userInfo: [AnyHashable: Any]) -> [String: Any] {
        let type = userInfo["type"] as? String ?? "unknown"
        let route = userInfo["route"] as? String ?? "unknown"
        return ["type": type, "route": route]
    }
}
