import SwiftUI

struct SmartAdvisorView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundStyle(.purple)
                Text("Smart Advisor")
                    .font(.title2)
                    .bold()
                Text("AI-powered recommendations coming soon")
                    .foregroundStyle(.secondary)
                    .padding()
            }
            .navigationTitle("Advisor")
        }
    }
}

#Preview {
    SmartAdvisorView()
}
