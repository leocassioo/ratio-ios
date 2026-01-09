//
//  AppNavigationState.swift
//  Ratio
//
//  Created by Codex on 08/01/26.
//

import Foundation
import Combine

@MainActor
final class AppNavigationState: ObservableObject {
    @Published var selectedTab: MainTab = .home

    func route(to tab: MainTab) {
        selectedTab = tab
    }
}
