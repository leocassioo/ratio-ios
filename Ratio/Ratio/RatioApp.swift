//
//  RatioApp.swift
//  Ratio
//
//  Created by Leonardo Figueiredo on 21/12/25.
//

import FirebaseAuth
import FirebaseCore
import FirebaseMessaging
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate {
    private lazy var usersStore = UsersStore()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        NotificationManager.shared.configure()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken, let userId = Auth.auth().currentUser?.uid else { return }
        Task {
            try? await usersStore.updateFCMToken(userId: userId, token: token)
        }
    }
}

@main
struct RatioApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @AppStorage("appLanguage") private var appLanguageRaw: String = AppLanguage.system.rawValue

    var body: some Scene {
        WindowGroup {
            let theme = AppTheme(rawValue: appThemeRaw) ?? .system
            let language = AppLanguage(rawValue: appLanguageRaw) ?? .system
            ContentView()
                .preferredColorScheme(theme.colorScheme)
                .environment(\.locale, language.locale ?? Locale.current)
        }
    }
}
