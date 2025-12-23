import Foundation
import Combine

@MainActor
class GroupsViewModel: ObservableObject {
    @Published var groups: [RatioGroup] = []
    @Published var isLoading = false
    
    func fetchGroups() async {
        isLoading = true
        // Simulating network delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // MOCK DATA matching User's Image
        self.groups = [
            RatioGroup(
                id: "1",
                name: "Family Netflix",
                totalAmount: 55.90,
                frequency: .monthly,
                members: [
                    GroupMember(id: "1", name: "You (Me)", photoUrl: nil, amountToPay: 13.97, status: .paid),
                    GroupMember(id: "2", name: "Alice", photoUrl: nil, amountToPay: 13.97, status: .paid),
                    GroupMember(id: "3", name: "Bob", photoUrl: nil, amountToPay: 13.97, status: .pending),
                    GroupMember(id: "4", name: "Charlie", photoUrl: nil, amountToPay: 13.97, status: .pending),
                    GroupMember(id: "5", name: "Dave", photoUrl: nil, amountToPay: 13.97, status: .pending)
                ],
                category: "Streaming"
            ),
            RatioGroup(
                id: "2",
                name: "Spotify Couple",
                totalAmount: 27.90,
                frequency: .monthly,
                members: [
                    GroupMember(id: "1", name: "You (Me)", photoUrl: nil, amountToPay: 13.95, status: .paid),
                    GroupMember(id: "6", name: "Sarah", photoUrl: nil, amountToPay: 13.95, status: .paid)
                ],
                category: "Music"
            )
        ]
        
        isLoading = false
    }
}
