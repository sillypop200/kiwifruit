import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack { FeedView() }
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            NavigationStack { ProfileView() }
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
            Text("Challenges")
                .tabItem {
                    Label("Challenges", systemImage: "flag.checkered")
                }
            Text("Focus")
                .tabItem {
                    Label("Focus", systemImage: "leaf.fill")
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
