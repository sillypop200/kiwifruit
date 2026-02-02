import Foundation

enum MockData {
    static let sampleUser = User(
        id: UUID(),
        username: "kiwi_botanist",
        displayName: "Kiwi Lover",
        avatarURL: URL(string: "https://picsum.photos/seed/avatar/100")
    )

    static func makePosts(count: Int, page: Int) -> [Post] {
        var posts: [Post] = []
        let base = page * count
        for i in 0..<count {
            let id = UUID()
            let imageURL = URL(string: "https://picsum.photos/seed/kiwi\(base + i)/600/600")!
            let post = Post(
                id: id,
                author: sampleUser,
                imageURL: imageURL,
                caption: "Fresh kiwi vibes #\(base + i)",
                likes: Int.random(in: 0...500),
                createdAt: Date().addingTimeInterval(TimeInterval(-((base + i) * 60)))
            )
            posts.append(post)
        }
        return posts
    }
}
