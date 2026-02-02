import SwiftUI

struct PostRow: View {
    let post: Post
    @Environment(\.likesStore) private var likesStore: LikesStore
    @Environment(\.postsStore) private var postsStore: PostsStore
    @Environment(\.sessionStore) private var session: SessionStore
    @State private var showingComments = false
    @Environment(\.commentsStore) private var commentsStore: CommentsStore

    // Whether current device/user liked this post (local store)
    var isLiked: Bool { likesStore.isLiked(post) }

    // Displayed likes: use server count plus optimistic +1 only while pending
    var displayedLikes: Int {
        if likesStore.isPending(post) {
            return post.likes + (isLiked ? 1 : 0)
        } else {
            return post.likes
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                NavigationLink(destination: ProfileView(user: post.author)) {
                    AsyncImage(url: post.author.avatarURL) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                        } else if phase.error != nil {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                }

                VStack(alignment: .leading) {
                    Text(post.author.displayName ?? post.author.username)
                        .font(.headline)
                    Text("@\(post.author.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            NavigationLink(destination: PostDetailView(post: post)) {
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
            }
            .frame(maxWidth: .infinity)
            .frame(height: 360)
            .clipped()
            .cornerRadius(8)

            HStack(spacing: 12) {
                Button(action: { Task { await toggleLike() } }) {
                    Label("Like", systemImage: isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(isLiked ? .red : .primary)
                }

                if session.userId == post.author.id {
                    Spacer()
                    Button(role: .destructive) {
                        Task { await deletePost() }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }

                Text("\(displayedLikes) likes")
                    .font(.subheadline)

                Spacer()

                Button(action: { showingComments = true }) {
                    Label("Comment", systemImage: "bubble.right")
                }
                .sheet(isPresented: $showingComments) {
                    CommentsView(post: post)
                }
            }

            if let caption = post.caption {
                Text(caption)
                    .font(.body)
            }

            // Inline comments (show all fetched comments for this post)
            let inlineComments = commentsStore.comments(for: post)
            if !inlineComments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(inlineComments) { c in
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.author.displayName ?? c.author.username)
                                    .font(.subheadline)
                                    .bold()
                                Text(c.text)
                                    .font(.body)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, 4)
            }

            // Safely unwrap optional createdAt
            if let createdAt = post.createdAt {
                Text(createdAt, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .task {
            await commentsStore.fetchForPost(post)
        }
    }

    // Toggle like with optimistic UI: update local LikesStore first, then call API and reconcile server count.
    private func toggleLike() async {
        // Prevent re-entrant like ops and track optimistic state
        likesStore.markPending(post.id)
        likesStore.toggle(post)
        do {
            if likesStore.isLiked(post) {
                let updated = try await AppAPI.shared.likePost(post.id)
                likesStore.clearPending(post.id)
                postsStore.updateLikes(postId: post.id, likes: updated)
            } else {
                let updated = try await AppAPI.shared.unlikePost(post.id)
                likesStore.clearPending(post.id)
                postsStore.updateLikes(postId: post.id, likes: updated)
            }
        } catch {
            // On failure, rollback local optimistic like and clear pending
            likesStore.toggle(post)
            likesStore.clearPending(post.id)
            print("Like/unlike failed: \(error)")
        }
    }

    private func deletePost() async {
        do {
            try await AppAPI.shared.deletePost(post.id)
            postsStore.removePost(postId: post.id)
        } catch {
            print("deletePost failed: \(error)")
        }
    }
}

struct PostRow_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PostRow(post: MockData.makePosts(count: 1, page: 0).first!)
                .previewLayout(.sizeThatFits)
                .padding()
        }
    }
}
