import Foundation
import Observation

@Observable @MainActor
final class FeedViewModel {
    private(set) var posts: [Post] = []
    private(set) var isLoading = false

    private var page = 0
    private let pageSize = 10

    func loadInitial() async {
        guard posts.isEmpty else { return }
        page = 0
        await fetchNext()
    }

    func prepend(_ post: Post) {
        posts.insert(post, at: 0)
    }

    func fetchNextIfNeeded(currentPost: Post) async {
        guard let idx = posts.firstIndex(where: { $0.id == currentPost.id }) else { return }
        let threshold = posts.count - 3
        if idx >= threshold {
            await fetchNext()
        }
    }

    private func fetchNext() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let new = try await APIClient.shared.fetchPosts(page: page, pageSize: pageSize)
            posts.append(contentsOf: new)
            page += 1
        } catch {
            print("Failed to fetch posts: \(error)")
        }
    }
}
