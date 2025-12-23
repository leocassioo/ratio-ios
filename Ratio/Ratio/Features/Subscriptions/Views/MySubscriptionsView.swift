import SwiftUI

struct MySubscriptionsView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "creditcard")
                    .font(.system(size: 60))
                    .foregroundStyle(.gray)
                Text("My Subscriptions (Coming Soon)")
                    .font(.title2)
                    .padding()
            }
            .navigationTitle("My Subscriptions")
        }
    }
}

#Preview {
    MySubscriptionsView()
}
