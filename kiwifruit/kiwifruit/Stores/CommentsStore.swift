import Foundation
import Observation
import SwiftUI

/// Simple comments store persisted in UserDefaults. Suitable for prototype/local usage.
@Observable @MainActor
final class CommentsStore {
    private let key = "kiwifruit.comments"
    private(set) var commentsByPost: [String: [Comment]] = [:]

    init() { load() }

    func comments(for post: Post) -> [Comment] {
        commentsByPost[post.id] ?? []
    }

    func addLocalComment(_ text: String, post: Post, author: User) {
        let c = Comment(id: UUID().uuidString, postId: post.id, author: author, text: text, createdAt: Date())
        commentsByPost[post.id, default: []].append(c)
        save()
    }

    func fetchForPost(_ post: Post) async {
        do {
            let fetched = try await AppAPI.shared.fetchComments(postId: post.id)
            commentsByPost[post.id] = fetched
            save()
        } catch {
            // ignore fetch errors for now; keep local comments
            print("fetchForPost failed: \(error)")
        }
    }

    /// Create a comment on the server; returns true if server call succeeded, false if fallback used.
    func createComment(_ text: String, post: Post, author: User?) async -> Bool {
        do {
            try await AppAPI.shared.createComment(postId: post.id, text: text)
            // refresh comments from server
            await fetchForPost(post)
            return true
        } catch {
            print("createComment failed: \(error)")
            // fallback to local add
            if let author = author {
                addLocalComment(text, post: post, author: author)
            }
            return false
        }
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
        if let decoded = try? decoder.decode([String: [Comment]].self, from: data) {
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
