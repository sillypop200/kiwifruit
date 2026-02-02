import Foundation
import Observation

/// PostsStore centralizes feed data so multiple views (feed, profile) share a single source of truth.
@Observable @MainActor
final class PostsStore {
    private(set) var posts: [Post] = []
    private(set) var isLoading = false

    private var page = 0
    private let pageSize = 10

    /// Load initial page (idempotent)
    func loadInitial(force: Bool = false) async {
        if !posts.isEmpty && !force { return }
        posts.removeAll()
        page = 0
        await fetchNext()
    }

    /// Fetch next page and append
    func fetchNext() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let new = try await AppAPI.shared.fetchPosts(page: page, pageSize: pageSize)
            // append while avoiding duplicates
            for p in new {
                if !posts.contains(where: { $0.id == p.id }) {
                    posts.append(p)
                }
            }
            page += 1
        } catch {
            print("PostsStore: fetchNext failed: \(error)")
        }
    }

    /// Prepend a newly created post (used after creating a post locally)
    func prepend(_ post: Post) {
        // remove existing copy if present, then insert at front
        posts.removeAll(where: { $0.id == post.id })
        posts.insert(post, at: 0)
    }

    /// Update likes count for a post (server-driven)
    func updateLikes(postId: UUID, likes: Int) {
        if let idx = posts.firstIndex(where: { $0.id == postId }) {
            var p = posts[idx]
            p.likes = likes
            posts[idx] = p
        }
    }

    /// Remove a post locally (after server deletion)
    func removePost(postId: UUID) {
        posts.removeAll(where: { $0.id == postId })
    }

    /// Return posts authored by a specific user
    func posts(for user: User) -> [Post] {
        posts.filter { $0.author.id == user.id }
    }
}

// Environment key so a single PostsStore can be injected into SwiftUI view hierarchy.
import SwiftUI

private struct PostsStoreKey: EnvironmentKey {
    static let defaultValue: PostsStore = PostsStore()
}

extension EnvironmentValues {
    var postsStore: PostsStore {
        get { self[PostsStoreKey.self] }
        set { self[PostsStoreKey.self] = newValue }
    }
}
