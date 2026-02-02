import Foundation

// Helper to build multipart body
fileprivate extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

protocol APIClientProtocol {
    func fetchPosts(page: Int, pageSize: Int) async throws -> [Post]
    /// Create a post. `imageData` is optional; if provided the client should upload it.
    func createPost(authorId: UUID, imageData: Data?, caption: String?) async throws -> Post
    func createSession(username: String) async throws -> (token: String, user: User)
    func likePost(_ postId: UUID) async throws -> Int
    func unlikePost(_ postId: UUID) async throws -> Int
}

final class MockAPIClient: APIClientProtocol {
    func fetchPosts(page: Int, pageSize: Int) async throws -> [Post] {
        // Simulate network latency
        try await Task.sleep(nanoseconds: 300 * 1_000_000)
        return MockData.makePosts(count: pageSize, page: page)
    }

    func createPost(authorId: UUID, imageData: Data?, caption: String?) async throws -> Post {
        try await Task.sleep(nanoseconds: 150 * 1_000_000)
        // If imageData provided, write to temporary file so AsyncImage can load via file URL during mock
        let imageURL: URL
        if let data = imageData {
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("kiwi_upload_\(UUID().uuidString).jpg")
            try data.write(to: tmp)
            imageURL = tmp
        } else {
            imageURL = URL(string: "https://picsum.photos/seed/kiwi/600/600")!
        }
        let post = Post(id: UUID(), author: MockData.sampleUser, imageURL: imageURL, caption: caption, likes: 0, createdAt: Date())
        return post
    }

    func likePost(_ postId: UUID) async throws -> Int {
        // Mock increment - return random-ish updated value
        try await Task.sleep(nanoseconds: 80 * 1_000_000)
        return Int.random(in: 1...500)
    }

    func unlikePost(_ postId: UUID) async throws -> Int {
        try await Task.sleep(nanoseconds: 80 * 1_000_000)
        return Int.random(in: 0...499)
    }

    func createSession(username: String) async throws -> (token: String, user: User) {
        try await Task.sleep(nanoseconds: 100 * 1_000_000)
        return (token: UUID().uuidString, user: MockData.sampleUser)
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
        // Use API v1 posts endpoint (returns snake_case fields)
        var comps = URLComponents(url: baseURL.appendingPathComponent("/api/posts"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "limit", value: String(pageSize))
        ]
        var req = URLRequest(url: comps.url!)
        if let token = authToken {
            req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, _) = try await session.data(for: req)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Post].self, from: data)
    }

    func createPost(authorId: UUID, imageData: Data?, caption: String?) async throws -> Post {
        let url = baseURL.appendingPathComponent("/api/posts")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        if let token = authToken {
            req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let data = imageData {
            // multipart/form-data upload
            let boundary = "Boundary-\(UUID().uuidString)"
            req.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            var body = Data()

            // authorId field
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"authorId\"\r\n\r\n")
            body.appendString("\(authorId.uuidString)\r\n")

            // caption field
            if let caption = caption {
                body.appendString("--\(boundary)\r\n")
                body.appendString("Content-Disposition: form-data; name=\"caption\"\r\n\r\n")
                body.appendString("\(caption)\r\n")
            }

            // file field
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n")
            body.appendString("Content-Type: image/jpeg\r\n\r\n")
            body.append(data)
            body.appendString("\r\n")

            body.appendString("--\(boundary)--\r\n")
            req.httpBody = body
        } else {
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
            var body: [String: Any] = [:]
            if let caption = caption { body["caption"] = caption }
            // No local image data -> allow sending external image_url later if needed
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, _) = try await session.data(for: req)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Post.self, from: data)
    }

    func likePost(_ postId: UUID) async throws -> Int {
        let url = baseURL.appendingPathComponent("/api/posts/\(postId)/like")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, _) = try await session.data(for: req)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let likes = decoded?["like_count"] as? Int { return likes }
        throw URLError(.badServerResponse)
    }

    func unlikePost(_ postId: UUID) async throws -> Int {
        let url = baseURL.appendingPathComponent("/api/posts/\(postId)/like")
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, _) = try await session.data(for: req)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let likes = decoded?["like_count"] as? Int { return likes }
        throw URLError(.badServerResponse)
    }

    func createSession(username: String) async throws -> (token: String, user: User) {
        let url = baseURL.appendingPathComponent("/sessions")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["username": username]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await session.data(for: req)
        // Expect { "token": "...", "user": { ... } } or variations (userId, id)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        let wrapperAny = try JSONSerialization.jsonObject(with: data)
        guard let wrapper = wrapperAny as? [String: Any], let token = wrapper["token"] as? String else {
            throw URLError(.badServerResponse)
        }

        // Case 1: server returned full `user` object
        if let userDict = wrapper["user"] as? [String: Any],
           let userData = try? JSONSerialization.data(withJSONObject: userDict) {
            let user = try decoder.decode(User.self, from: userData)
            return (token: token, user: user)
        }

        // Case 2: server returned an id (userId / user_id / id). Create a minimal User so client doesn't crash.
        if let idStr = (wrapper["userId"] as? String) ?? (wrapper["user_id"] as? String) ?? (wrapper["id"] as? String) {
            if let uuid = UUID(uuidString: idStr) {
                let user = User(id: uuid, username: "", displayName: nil, avatarURL: nil)
                return (token: token, user: user)
            } else {
                // fallback: create a placeholder UUID to satisfy the model
                let user = User(id: UUID(), username: "", displayName: nil, avatarURL: nil)
                return (token: token, user: user)
            }
        }

        // Unknown shape
        throw URLError(.badServerResponse)
    }
}

enum APIClient {
    /// Default shared client. Swap to `RESTAPIClient(baseURL:)` when you have a backend.
    static var shared: APIClientProtocol = MockAPIClient()
}
