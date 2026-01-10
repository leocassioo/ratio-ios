//
//  GroupMember.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import Foundation

struct GroupMember: Identifiable, Equatable {
    let id: String
    let name: String
    let amount: Double
    let status: GroupMemberStatus
    let userId: String?
    let receiptURL: String?
    let submittedAt: Date?
    let approvedAt: Date?
}
