//
//  GroupAvatarStack.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI

struct GroupAvatarStack: View {
    let members: [GroupMember]

    var body: some View {
        ZStack {
            ForEach(Array(members.prefix(4).enumerated()), id: \.offset) { index, member in
                MemberAvatarView(name: member.name)
                    .frame(width: 30, height: 30)
                    .padding(2)
                    .background(
                        Circle()
                            .fill(Color(.secondarySystemBackground))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color(.separator).opacity(0.6), lineWidth: 1)
                    )
                    .offset(x: CGFloat(index) * 12)
                    .zIndex(Double(members.count - index))
            }
        }
        .frame(width: 72, height: 30, alignment: .leading)
    }
}
