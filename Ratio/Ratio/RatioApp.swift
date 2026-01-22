//
//  RatioApp.swift
//  Ratio
//
//  Created by Leonardo Figueiredo on 21/12/25.
//

import FirebaseAuth
import FirebaseCore
import FirebaseMessaging
import FirebaseRemoteConfig
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate {
    private lazy var usersStore = UsersStore()
    private let preferencesStore = PreferencesStore.shared

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        RemoteConfigService.shared.fetchAndActivate()
        Messaging.messaging().delegate = self
        NotificationManager.shared.configure()
        NotificationManager.shared.registerForRemoteNotificationsIfAuthorized()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        let previousToken = preferencesStore.lastFcmToken()
        preferencesStore.setLastFcmToken(token)
        guard let userId = Auth.auth().currentUser?.uid else { return }
        Task {
            if let previousToken, previousToken != token {
                try? await usersStore.removeFCMToken(userId: userId, token: previousToken)
            }
            try? await usersStore.updateFCMToken(userId: userId, token: token)
        }
    }
}

@main
struct RatioApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage(PreferencesStore.PrefKey.hasSeenOnboarding) private var hasSeenOnboarding: Bool = false
    @AppStorage(PreferencesStore.PrefKey.appTheme) private var appThemeRaw: String = AppTheme.system.rawValue
    @AppStorage(PreferencesStore.PrefKey.appLanguage) private var appLanguageRaw: String = AppLanguage.system.rawValue
    @AppStorage(PreferencesStore.PrefKey.didSkipPushPermission) private var didSkipPushPermission: Bool = false
    @StateObject private var pushPermissionState = PushPermissionState()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            let theme = AppTheme(rawValue: appThemeRaw) ?? .system
            let language = AppLanguage(rawValue: appLanguageRaw) ?? .system
            Group {
                if hasSeenOnboarding {
                    switch pushPermissionState.status {
                    case .unknown:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .notDetermined:
                        if didSkipPushPermission {
                            ContentView()
                        } else {
                        PushPermissionView(
                            onRequestDone: {
                            pushPermissionState.refresh()
                            },
                            onSkip: {
                                didSkipPushPermission = true
                            }
                        )
                        }
                    case .authorized, .denied:
                        ContentView()
                    }
                } else {
                    OnboardingView {
                        hasSeenOnboarding = true
                    }
                }
            }
            .preferredColorScheme(theme.colorScheme)
            .environment(\.locale, language.locale ?? Locale.current)
            .environmentObject(subscriptionManager)
            .environmentObject(router)
            .onAppear {
                pushPermissionState.refresh()
            }
        }
    }
}
