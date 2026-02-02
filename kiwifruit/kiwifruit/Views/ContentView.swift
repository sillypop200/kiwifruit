import SwiftUI

struct ContentView: View {
    @Environment(\.sessionStore) private var session: SessionStore
    @Environment(\.postsStore) private var postsStore: PostsStore
    @State private var showingLogin = false
    @State private var selection: Int = 0

    private var currentUser: User {
        if let user = session.currentUser { return user }
        if let id = session.userId, let user = postsStore.posts.first(where: { $0.author.id == id })?.author {
            return user
        }
        return MockData.sampleUser
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { FeedView() }
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            NavigationStack { ProfileView(user: currentUser) }
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(1)

            Text("Challenges")
                .tabItem { Label("Challenges", systemImage: "flag.checkered") }
                .tag(2)

            Text("Focus")
                .tabItem { Label("Focus", systemImage: "leaf.fill") }
                .tag(3)
        }
        .onAppear {
            // Show login until we have a validated session and a userId
            showingLogin = !(session.isValidSession && session.userId != nil)
            if session.isValidSession && session.userId != nil { Task { await postsStore.loadInitial() } }
        }
        .onChange(of: session.userId) { new in
            showingLogin = !(session.isValidSession && new != nil)
            if new != nil {
                selection = 1
                Task { await postsStore.loadInitial() }
            }
        }
        .onChange(of: session.isValidSession) { valid in
            showingLogin = !(valid && session.userId != nil)
            if valid && session.userId != nil {
                selection = 1
                Task { await postsStore.loadInitial() }
            }
        }
        .fullScreenCover(isPresented: $showingLogin) {
            LoginView()
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
