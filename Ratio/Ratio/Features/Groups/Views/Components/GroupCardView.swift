import SwiftUI

struct GroupCardView: View {
    let group: RatioGroup
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text("Total: \(group.totalAmount.formatted(.currency(code: "BRL"))) / month")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Mini Avatars
                HStack(spacing: -10) {
                    ForEach(group.members.prefix(3)) { member in
                        Circle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 30, height: 30)
                            .overlay(Text(member.name.prefix(1)).font(.caption).foregroundStyle(.primary))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(uiColor: .secondarySystemGroupedBackground), lineWidth: 2))
                    }
                    if group.members.count > 3 {
                         Circle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 30, height: 30)
                            .overlay(Text("+\(group.members.count - 3)").font(.caption).foregroundStyle(.primary))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(uiColor: .secondarySystemGroupedBackground), lineWidth: 2))
                    }
                }
            }
            .padding()
            
            Divider()
                .padding(.horizontal)
            
            // Members List
            VStack(spacing: 12) {
                ForEach(group.members) { member in
                    MemberRowView(member: member)
                }
            }
            .padding()
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12) // More standard corner radius
        .shadow(color: Color.black.opacity(colorScheme == .light ? 0.05 : 0.0), radius: 5, x: 0, y: 2) // Subtle shadow only in light mode
    }
}

#Preview {
    let sample = RatioGroup(
        id: "1",
        name: "Family Netflix",
        totalAmount: 55.90,
        frequency: .monthly,
        members: [
            GroupMember(id: "1", name: "You (Me)", photoUrl: nil, amountToPay: 13.97, status: .paid),
            GroupMember(id: "2", name: "Alice", photoUrl: nil, amountToPay: 13.97, status: .paid),
            GroupMember(id: "3", name: "Bob", photoUrl: nil, amountToPay: 13.97, status: .pending),
            GroupMember(id: "4", name: "Charlie", photoUrl: nil, amountToPay: 13.97, status: .pending)
        ],
        category: "Streaming"
    )
    
    ZStack {
        Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
        GroupCardView(group: sample)
            .padding()
    }
}
