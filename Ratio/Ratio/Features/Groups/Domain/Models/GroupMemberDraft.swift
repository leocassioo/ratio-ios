//
//  GroupMemberDraft.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import Foundation

struct GroupMemberDraft: Identifiable, Equatable {
    let id: String
    var name: String
    var amountText: String
    var status: GroupMemberStatus
    var userId: String?
}

extension GroupMemberDraft {
    var amountValue: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
}
