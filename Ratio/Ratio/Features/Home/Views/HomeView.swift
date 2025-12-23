import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "house")
                    .font(.system(size: 60))
                    .foregroundStyle(.gray)
                Text("Home (Coming Soon)")
                    .font(.title2)
                    .padding()
            }
            .navigationTitle("Home")
        }
    }
}

#Preview {
    HomeView()
}
