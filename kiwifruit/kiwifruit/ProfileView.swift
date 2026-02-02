import SwiftUI

struct ProfileView: View {
    let user: User

    // For demo we reuse MockData
    private var posts: [Post] { MockData.makePosts(count: 12, page: 0) }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

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
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProfileView(user: MockData.sampleUser)
        }
    }
}
