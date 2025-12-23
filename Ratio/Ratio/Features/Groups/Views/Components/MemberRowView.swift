import SwiftUI

struct MemberRowView: View {
    let member: GroupMember
    
    var body: some View {
        HStack {
            // Avatar
            Circle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    if let url = member.photoUrl {
                        AsyncImage(url: URL(string: url)) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Text(member.name.prefix(1))
                        }
                    } else {
                        Text(member.name.prefix(1))
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                }
                .clipShape(Circle())
            
            // Name & Status
            VStack(alignment: .leading, spacing: 4) {
                Text(member.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text(member.status.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }
            
            Spacer()
            
            // Amount
            Text(member.amountToPay, format: .currency(code: "BRL"))
                .font(.subheadline)
                .bold()
                .foregroundStyle(.primary)
                .padding(.trailing, 8)
            
            // Action Button / Status Icon
            Group {
                if member.status == .paid {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                } else {
                    Button {
                        // Action to remind or pay
                    } label: {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    var statusColor: Color {
        switch member.status {
        case .paid: return .green
        case .pending: return .yellow
        case .late: return .red
        }
    }
}

#Preview {
    ZStack {
        Color.black
        MemberRowView(member: GroupMember(id: "1", name: "Alice", photoUrl: nil, amountToPay: 13.97, status: .pending))
            .padding()
    }
}
