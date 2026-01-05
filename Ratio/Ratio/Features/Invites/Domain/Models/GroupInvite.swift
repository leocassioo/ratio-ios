//
//  GroupInvite.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import Foundation

struct GroupInvite: Identifiable, Equatable {
    let id: String
    let groupId: String
    let createdBy: String
    let createdAt: Date
    let expiresAt: Date
    let maxUses: Int
    let usesCount: Int
}
