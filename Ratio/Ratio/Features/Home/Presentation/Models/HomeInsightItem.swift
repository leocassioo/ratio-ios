//
//  HomeInsightItem.swift
//  Ratio
//
//  Created by Codex on 09/01/26.
//

import Foundation

struct HomeInsightItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let detail: String
    let destination: MainTab?
}
