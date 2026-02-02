import SwiftUI

struct PostRow: View {
    let post: Post
    @Environment(\.likesStore) private var likesStore: LikesStore

    var isLiked: Bool { likesStore.isLiked(post) }

    var displayedLikes: Int {
        post.likes + (isLiked ? 1 : 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                NavigationLink(value: post.author) {
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
            .frame(maxWidth: .infinity)
            .frame(height: 360)
            .clipped()
            .cornerRadius(8)

            HStack(spacing: 12) {
                Button(action: { likesStore.toggle(post) }) {
                    Label("Like", systemImage: isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(isLiked ? .red : .primary)
                }

                Text("\(displayedLikes) likes")
                    .font(.subheadline)

                Spacer()
            }

            if let caption = post.caption {
                Text(caption)
                    .font(.body)
            }

            Text(post.createdAt, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
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
