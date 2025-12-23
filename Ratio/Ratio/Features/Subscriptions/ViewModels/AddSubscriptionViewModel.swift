import Foundation
import Combine

@MainActor
class AddSubscriptionViewModel: ObservableObject {
    @Published var name = ""
    @Published var amountString = ""
    @Published var billingDay = 1
    @Published var frequency: BillingFrequency = .monthly
    @Published var category = "Streaming"
    @Published var isLoading = false
    
    private let service = SubscriptionService.shared
    
    func saveSubscription(ownerId: String) async -> Bool {
        guard let amount = Double(amountString), !name.isEmpty else { return false }
        
        isLoading = true
        
        let newSub = Subscription(
            name: name,
            totalAmount: amount,
            billingDay: billingDay,
            frequency: frequency,
            ownerId: ownerId,
            groupId: nil,
            category: category,
            createdAt: Date()
        )
        
        do {
            try service.addSubscription(newSub)
            isLoading = false
            return true
        } catch {
            print("Error saving: \(error)")
            isLoading = false
            return false
        }
    }
}
