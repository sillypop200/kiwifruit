import Foundation

protocol APIClientProtocol {
    func fetchPosts(page: Int, pageSize: Int) async throws -> [Post]
    func createPost(authorId: UUID, imageURL: URL, caption: String?) async throws -> Post
    func createSession(username: String) async throws -> (token: String, userId: UUID)
}

final class MockAPIClient: APIClientProtocol {
    func fetchPosts(page: Int, pageSize: Int) async throws -> [Post] {
        // Simulate network latency
        try await Task.sleep(nanoseconds: 300 * 1_000_000)
        return MockData.makePosts(count: pageSize, page: page)
    }

    func createPost(authorId: UUID, imageURL: URL, caption: String?) async throws -> Post {
        try await Task.sleep(nanoseconds: 150 * 1_000_000)
        let post = Post(id: UUID(), author: MockData.sampleUser, imageURL: imageURL, caption: caption, likes: 0, createdAt: Date())
        return post
    }

    func createSession(username: String) async throws -> (token: String, userId: UUID) {
        try await Task.sleep(nanoseconds: 100 * 1_000_000)
        return (token: UUID().uuidString, userId: MockData.sampleUser.id)
    }
}

/// A simple REST API client implementation using URLSession and async/await.
final class RESTAPIClient: APIClientProtocol {
    let baseURL: URL
    let session: URLSession
    private(set) var authToken: String?

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func setAuthToken(_ token: String?) {
        self.authToken = token
    }

    func fetchPosts(page: Int, pageSize: Int) async throws -> [Post] {
        var comps = URLComponents(url: baseURL.appendingPathComponent("/posts"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "pageSize", value: String(pageSize))
        ]
        var req = URLRequest(url: comps.url!)
        if let token = authToken {
            req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, _) = try await session.data(for: req)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Post].self, from: data)
    }

    func createPost(authorId: UUID, imageURL: URL, caption: String?) async throws -> Post {
        let url = baseURL.appendingPathComponent("/posts")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let body: [String: Any] = [
            "authorId": authorId.uuidString,
            "imageURL": imageURL.absoluteString,
            "caption": caption ?? NSNull()
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await session.data(for: req)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Post.self, from: data)
    }

    func createSession(username: String) async throws -> (token: String, userId: UUID) {
        let url = baseURL.appendingPathComponent("/sessions")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["username": username]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await session.data(for: req)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let token = decoded?["token"] as? String,
              let userIdString = decoded?["userId"] as? String,
              let userId = UUID(uuidString: userIdString) else {
            throw URLError(.badServerResponse)
        }
        return (token: token, userId: userId)
    }
}

enum APIClient {
    /// Default shared client. Swap to `RESTAPIClient(baseURL:)` when you have a backend.
    static var shared: APIClientProtocol = MockAPIClient()
}
