import Foundation
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var subscriptions: [Subscription] = []
    @Published var isLoading = false
    @Published var totalMonthlyCost: Double = 0.0
    
    private let service = SubscriptionService.shared
    
    func fetchSubscriptions(userId: String) async {
        isLoading = true
        do {
            subscriptions = try await service.fetchSubscriptions(for: userId)
            calculateTotal()
        } catch {
            print("Error fetching docs: \(error)")
        }
        isLoading = false
    }
    
    private func calculateTotal() {
        // Simple logic: Sum all. To improve: normalize weekly/yearly to monthly.
        totalMonthlyCost = subscriptions.reduce(0) { $0 + $1.totalAmount }
    }
    
    func delete(at offsets: IndexSet) {
        // TODO: Implement delete in Service and UI
    }
}
