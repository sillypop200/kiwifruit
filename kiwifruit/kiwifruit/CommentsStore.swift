import Foundation
import Observation
import SwiftUI

/// Simple comments store persisted in UserDefaults. Suitable for prototype/local usage.
@Observable
final class CommentsStore {
    private let key = "kiwifruit.comments"
    private(set) var commentsByPost: [UUID: [Comment]] = [:]

    init() { load() }

    func comments(for post: Post) -> [Comment] {
        commentsByPost[post.id] ?? []
    }

    func addComment(_ text: String, post: Post, author: User) {
        let c = Comment(id: UUID(), postId: post.id, author: author, text: text, createdAt: Date())
        commentsByPost[post.id, default: []].append(c)
        save()
    }

    private func save() {
        // Persist as array of dicts
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(commentsByPost) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([UUID: [Comment]].self, from: data) {
            commentsByPost = decoded
        }
    }
}

private struct CommentsStoreKey: EnvironmentKey {
    static let defaultValue: CommentsStore = CommentsStore()
}

extension EnvironmentValues {
    var commentsStore: CommentsStore {
        get { self[CommentsStoreKey.self] }
        set { self[CommentsStoreKey.self] = newValue }
    }
}
