//
//  PushPermissionState.swift
//  Ratio
//
//  Created by Codex on 23/12/25.
//

import Foundation
import UserNotifications
import Combine

@MainActor
final class PushPermissionState: ObservableObject {
    enum Status {
        case unknown
        case notDetermined
        case authorized
        case denied
    }

    @Published private(set) var status: Status = .unknown

    func refresh() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let newStatus: Status
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                newStatus = .authorized
            case .denied:
                newStatus = .denied
            case .notDetermined:
                newStatus = .notDetermined
            @unknown default:
                newStatus = .notDetermined
            }
            DispatchQueue.main.async {
                self.status = newStatus
            }
        }
    }
}
