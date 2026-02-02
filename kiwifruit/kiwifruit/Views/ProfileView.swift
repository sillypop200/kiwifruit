import SwiftUI

struct ProfileView: View {
    let user: User

    @Environment(\.postsStore) private var postsStore: PostsStore
    // Show posts authored by this user from the shared posts store
    private var posts: [Post] { postsStore.posts(for: user) }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    @Environment(\.sessionStore) private var session: SessionStore
    @State private var showingLogin = false
    @State private var showingCreate = false
    @State private var followers: [User] = []
    @State private var following: [User] = []
    @State private var isFollowing: Bool = false
    @State private var followPending: Bool = false
    @State private var showingFollowersSheet = false
    @State private var showingFollowingSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    AsyncImage(url: user.avatarURL) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else if phase.error != nil {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())

                    VStack(alignment: .leading) {
                        Text(user.displayName ?? user.username)
                            .font(.title2)
                            .bold()
                        Text("@\(user.username)")
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading) {
                        Button(action: { showingFollowersSheet = true }) {
                            Text("Followers: \(followers.count)")
                        }
                        .buttonStyle(.plain)
                        Button(action: { showingFollowingSheet = true }) {
                            Text("Following: \(following.count)")
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    if session.userId == nil {
                        Button("Sign In") { showingLogin = true }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                    } else if session.userId == user.id {
                        HStack(spacing: 8) {
                            Button(action: { showingCreate = true }) {
                                Image(systemName: "plus.app")
                                Text("New Post")
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Sign Out") { session.clear() }
                                .buttonStyle(.bordered)
                        }
                    } else {
                        if isFollowing {
                            Button(action: { Task { await toggleFollow() } }) {
                                Text("Unfollow")
                            }
                            .disabled(followPending)
                            .buttonStyle(.bordered)
                        } else {
                            Button(action: { Task { await toggleFollow() } }) {
                                Text("Follow")
                            }
                            .disabled(followPending)
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }

                Text("Posts")
                    .font(.headline)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(posts) { post in
                        AsyncImage(url: post.imageURL) { phase in
                            switch phase {
                            case .empty:
                                ZStack { Color(.systemGray5); ProgressView() }
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .failure:
                                ZStack { Color(.systemGray4); Image(systemName: "photo") }
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(height: 140)
                        .clipped()
                        .cornerRadius(6)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(user.displayName ?? user.username)
        .sheet(isPresented: $showingLogin) {
            LoginView()
        }
        .sheet(isPresented: $showingCreate) {
            CreatePostView(isPresented: $showingCreate) { post in
                postsStore.prepend(post)
            }
            .environment(\.postsStore, postsStore)
        }
        .sheet(isPresented: $showingFollowersSheet) {
            NavigationStack {
                List(followers) { u in
                    HStack {
                        AsyncImage(url: u.avatarURL) { ph in
                            if let image = ph.image {
                                image.resizable().scaledToFill()
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                            }
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        Text(u.displayName ?? u.username)
                    }
                }
                .navigationTitle("Followers")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { showingFollowersSheet = false } } }
            }
        }
        .sheet(isPresented: $showingFollowingSheet) {
            NavigationStack {
                List(following) { u in
                    HStack {
                        AsyncImage(url: u.avatarURL) { ph in
                            if let image = ph.image {
                                image.resizable().scaledToFill()
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                            }
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        Text(u.displayName ?? u.username)
                    }
                }
                .navigationTitle("Following")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { showingFollowingSheet = false } } }
            }
        }
        .task {
            await loadFollowLists()
        }
    }

    // Load followers/following lists and compute following state
    private func loadFollowLists() async {
        do {
            let f = try await AppAPI.shared.fetchFollowers(username: user.username)
            let fo = try await AppAPI.shared.fetchFollowing(username: user.username)
            DispatchQueue.main.async {
                self.followers = f
                self.following = fo
                if let cur = session.userId {
                    self.isFollowing = f.contains(where: { $0.id == cur })
                } else {
                    self.isFollowing = false
                }
            }
        } catch {
            print("loadFollowLists failed: \(error)")
        }
    }

    private func toggleFollow() async {
        guard let cur = session.userId else { return }
        followPending = true
        defer { followPending = false }
        do {
            if isFollowing {
                try await AppAPI.shared.unfollowUser(user.username)
            } else {
                try await AppAPI.shared.followUser(user.username)
            }
            await loadFollowLists()
        } catch {
            print("toggleFollow failed: \(error)")
        }
    }

}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProfileView(user: MockData.sampleUser)
        }
    }
}
