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
                    .frame(width: 28, height: 28)
                    .offset(x: CGFloat(index) * -10)
            }
        }
        .frame(width: 60, height: 28, alignment: .trailing)
    }
}
