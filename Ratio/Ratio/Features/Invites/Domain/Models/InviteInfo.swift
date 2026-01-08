//
//  InviteInfo.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import Foundation

struct InviteInfo: Identifiable, Equatable {
    let id: String
    let groupId: String
    let groupName: String
    let createdBy: String
    let expiresAt: Date
    let maxUses: Int
    let usesCount: Int
    let status: String
}
