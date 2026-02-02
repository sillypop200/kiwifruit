import SwiftUI

struct PostDetailView: View {
    let post: Post
    @Environment(\.commentsStore) private var commentsStore: CommentsStore
    @Environment(\.likesStore) private var likesStore: LikesStore
    @Environment(\.postsStore) private var postsStore: PostsStore
    @Environment(\.sessionStore) private var session: SessionStore
    @State private var comments: [Comment] = []
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    AsyncImage(url: post.author.avatarURL) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() }
                        else { Image(systemName: "person.crop.circle.fill").resizable() }
                    }
                    .frame(width: 48, height: 48).clipShape(Circle())

                    VStack(alignment: .leading) {
                        Text(post.author.displayName ?? post.author.username).font(.headline)
                        Text("@\(post.author.username)").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                }

                AsyncImage(url: post.imageURL) { phase in
                    switch phase {
                    case .empty: ZStack { Color(.systemGray5); ProgressView() }
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure: ZStack { Color(.systemGray4); Image(systemName: "photo") }
                    @unknown default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity).frame(height: 360).clipped().cornerRadius(8)

                HStack(spacing: 12) {
                    Button(action: { Task { await toggleLike() } }) {
                        Label("Like", systemImage: likesStore.isLiked(post) ? "heart.fill" : "heart")
                    }
                    Text("\(post.likes) likes").font(.subheadline)
                    Spacer()
                }

                if let caption = post.caption { Text(caption).font(.body) }

                Divider()
                Text("Comments").font(.headline)

                if isLoading { ProgressView() }

                ForEach(comments) { c in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(c.author.displayName ?? c.author.username).font(.subheadline).bold()
                        Text(c.text).font(.body)
                        Text(c.createdAt, style: .time).font(.caption2).foregroundColor(.secondary)
                    }.padding(.vertical, 6)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Post")
        .task { await loadComments() }
    }

    private func loadComments() async {
        isLoading = true
        await commentsStore.fetchForPost(post)
        comments = commentsStore.comments(for: post)
        isLoading = false
    }

    private func toggleLike() async {
        likesStore.toggle(post)
        do {
            if likesStore.isLiked(post) {
                let updated = try await AppAPI.shared.likePost(post.id)
                postsStore.updateLikes(postId: post.id, likes: updated)
            } else {
                let updated = try await AppAPI.shared.unlikePost(post.id)
                postsStore.updateLikes(postId: post.id, likes: updated)
            }
        } catch {
            likesStore.toggle(post)
            print("toggleLike failed: \(error)")
        }
    }
}

struct PostDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { PostDetailView(post: MockData.makePosts(count: 1, page: 0).first!) }
    }
}
