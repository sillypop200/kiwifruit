import SwiftUI

struct ContentView: View {
    @Environment(\.sessionStore) private var session: SessionStore
    @Environment(\.postsStore) private var postsStore: PostsStore
    // Show login while there is no validated session/user
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
            if session.isValidSession && session.userId != nil { Task { await postsStore.loadInitial() } }
        }
        .onChange(of: session.userId) { new in
            if new != nil { selection = 1; Task { await postsStore.loadInitial() } }
        }
        .onChange(of: session.isValidSession) { valid in
            if valid && session.userId != nil { selection = 1; Task { await postsStore.loadInitial() } }
        }
        .fullScreenCover(isPresented: Binding(get: { session.forceFreshLogin || !(session.isValidSession && session.userId != nil) }, set: { _ in })) {
            LoginView()
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
