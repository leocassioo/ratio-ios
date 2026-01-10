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
    @Published var pendingGroupId: String?

    func route(to tab: MainTab, groupId: String? = nil) {
        selectedTab = tab
        pendingGroupId = groupId
    }
}
