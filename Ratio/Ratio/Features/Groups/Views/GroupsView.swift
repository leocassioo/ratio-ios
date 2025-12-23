import SwiftUI

struct GroupsView: View {
    @StateObject private var viewModel = GroupsViewModel()
    @State private var showingAddSheet = false
    var userId: String
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if viewModel.groups.isEmpty && !viewModel.isLoading {
                        // Empty State
                        ContentUnavailableView(
                            "No Groups Yet",
                            systemImage: "person.3",
                            description: Text("Create a group to start splitting expenses.")
                        )
                        .padding(.top, 40)
                    } else {
                        ForEach(viewModel.groups) { group in
                            GroupCardView(group: group)
                        }
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Groups")
            .toolbar {
                Button {
                    showingAddSheet.toggle()
                } label: {
                    Label(
                        NSLocalizedString("shopping_toolbar_add_item", comment: "Add item"),
                        systemImage: "plus.circle.fill"
                    )
                }
            }
            // Temporarily using Subscription Add View, but we ideally need a "Create Group" logic
            .sheet(isPresented: $showingAddSheet) {
                AddSubscriptionView(ownerId: userId)
            }
            .task {
                await viewModel.fetchGroups()
            }
        }
    }
}

#Preview {
    GroupsView(userId: "test")
        .preferredColorScheme(.dark)
}
