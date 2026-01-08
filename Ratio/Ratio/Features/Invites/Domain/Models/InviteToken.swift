//
//  InviteToken.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import Foundation

struct InviteToken: Identifiable, Equatable {
    let id: String

    init(_ value: String) {
        self.id = value
    }
}
