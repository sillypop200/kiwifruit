import Foundation

enum MockData {
    static let sampleUser = User(
        id: UUID().uuidString,
        username: "kiwi_botanist",
        displayName: "Kiwi Lover",
        avatarURL: URL(string: "https://picsum.photos/seed/avatar/100")
    )

    static func makePosts(count: Int, page: Int) -> [Post] {
        var posts: [Post] = []
        let base = page * count
        for i in 0..<count {
            let id = UUID().uuidString
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

    static func makeComments(for postId: String) -> [Comment] {
        var comments: [Comment] = []
        let authors = [sampleUser, User(id: UUID().uuidString, username: "reader1", displayName: "Reader 1", avatarURL: nil), User(id: UUID().uuidString, username: "reader2", displayName: "Reader 2", avatarURL: nil)]
        for i in 0..<3 {
            let c = Comment(id: UUID().uuidString, postId: postId, author: authors[i % authors.count], text: "Nice post! (\(i))", createdAt: Date().addingTimeInterval(TimeInterval(-i * 60)))
            comments.append(c)
        }
        return comments
    }
}
