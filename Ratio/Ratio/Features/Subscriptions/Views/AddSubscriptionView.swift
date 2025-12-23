import SwiftUI

struct AddSubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = AddSubscriptionViewModel()
    var ownerId: String
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Service Details") {
                    TextField("Name (e.g. Netflix)", text: $viewModel.name)
                    TextField("Amount (e.g. 19.90)", text: $viewModel.amountString)
                        .keyboardType(.decimalPad)
                    
                    Picker("Category", selection: $viewModel.category) {
                        Text("Streaming").tag("Streaming")
                        Text("Utilities").tag("Utilities")
                        Text("Software").tag("Software")
                        Text("Gym").tag("Gym")
                    }
                }
                
                Section("Billing Cycle") {
                    Picker("Frequency", selection: $viewModel.frequency) {
                        ForEach(BillingFrequency.allCases) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                    
                    Stepper("Billing Day: \(viewModel.billingDay)", value: $viewModel.billingDay, in: 1...31)
                }
            }
            .navigationTitle("New Subscription")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let success = await viewModel.saveSubscription(ownerId: ownerId)
                            if success { dismiss() }
                        }
                    }
                    .disabled(viewModel.name.isEmpty || viewModel.amountString.isEmpty)
                }
            }
        }
    }
}
