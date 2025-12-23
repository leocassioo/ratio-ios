//
//  RatioApp.swift
//  Ratio
//
//  Created by Leonardo Figueiredo on 21/12/25.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
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
