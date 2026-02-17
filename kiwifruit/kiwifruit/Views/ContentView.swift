import SwiftUI

struct ContentView: View {
    @Environment(\.sessionStore) private var session: SessionStore
    @Environment(\.postsStore) private var postsStore: PostsStore
    // Show login while there is no validated session/user
    @State private var selection: Int = 0
    
    @State private var bookSearchViewModel = BookSearchViewModel(api: AppAPI.shared)

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
            NavigationStack { DiscoverView(bookSearchViewModel: bookSearchViewModel) }
                .tabItem { Label("Discover", systemImage: "sparkles") }
                .tag(1)

            NavigationStack { ProfileView(user: currentUser) }
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(2)

            Text("Challenges")
                .tabItem { Label("Challenges", systemImage: "flag.checkered") }
                .tag(3)

            Text("Focus")
                .tabItem { Label("Focus", systemImage: "leaf.fill") }
                .tag(4)
        }
        .onAppear {
            if session.isValidSession && session.userId != nil { Task { await postsStore.loadInitial() } }
        }
        .onChange(of: session.userId) { new in
            if new != nil { selection = 2; Task { await postsStore.loadInitial(force: true) } }
        }
        .onChange(of: session.isValidSession) { valid in
            if valid && session.userId != nil { selection = 2; Task { await postsStore.loadInitial(force: true) } }
        }
        .fullScreenCover(isPresented: Binding(get: { !(session.isValidSession && session.userId != nil) }, set: { _ in })) {
            LoginView()
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
