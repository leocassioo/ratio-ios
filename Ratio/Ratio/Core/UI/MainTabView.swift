import SwiftUI

struct MainTabView: View {
    var userId: String
    @State private var selectedTab: Tab = .groups
    
    enum Tab {
        case home, mySubs, groups, advisor
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(Tab.home)
            
            MySubscriptionsView()
                .tabItem {
                    Label("My Subs", systemImage: "list.bullet.rectangle")
                }
                .tag(Tab.mySubs)
            
            GroupsView(userId: userId)
                .tabItem {
                    Label("Groups", systemImage: "person.3")
                }
                .tag(Tab.groups)
            
            SmartAdvisorView()
                .tabItem {
                    Label("Advisor", systemImage: "sparkles")
                }
                .tag(Tab.advisor)
        }
    }
}

#Preview {
    MainTabView(userId: "test")
}
