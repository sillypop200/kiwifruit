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
    func createSession(username: String, password: String) async throws -> (token: String, user: User)
    func createAccount(username: String, password: String, fullname: String?) async throws -> User
    func likePost(_ postId: UUID) async throws -> Int
    func unlikePost(_ postId: UUID) async throws -> Int
    func fetchComments(postId: UUID) async throws -> [Comment]
    func createComment(postId: UUID, text: String) async throws -> Void
    func deleteComment(commentId: UUID) async throws -> Void
    func deletePost(_ postId: UUID) async throws -> Void
}

/// Simple in-memory/mock client used in previews and when no backend is configured.
final class MockAPIClient: APIClientProtocol {
    func fetchPosts(page: Int, pageSize: Int) async throws -> [Post] {
        try await Task.sleep(nanoseconds: 200 * 1_000_000)
        return MockData.makePosts(count: pageSize, page: page)
    }

    func createPost(authorId: UUID, imageData: Data?, caption: String?) async throws -> Post {
        try await Task.sleep(nanoseconds: 150 * 1_000_000)
        let imageURL: URL
        if let data = imageData {
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("kiwi_upload_\(UUID().uuidString).jpg")
            try data.write(to: tmp)
            imageURL = tmp
        } else {
            imageURL = URL(string: "https://picsum.photos/seed/kiwi/600/600")!
        }
        return Post(id: UUID(), author: MockData.sampleUser, imageURL: imageURL, caption: caption, likes: 0, createdAt: Date())
    }

    func likePost(_ postId: UUID) async throws -> Int { try await Task.sleep(nanoseconds: 80 * 1_000_000); return Int.random(in: 1...500) }
    func unlikePost(_ postId: UUID) async throws -> Int { try await Task.sleep(nanoseconds: 80 * 1_000_000); return Int.random(in: 0...499) }

    func createSession(username: String, password: String) async throws -> (token: String, user: User) {
        try await Task.sleep(nanoseconds: 120 * 1_000_000)
        return (token: UUID().uuidString, user: MockData.sampleUser)
    }

    func createAccount(username: String, password: String, fullname: String?) async throws -> User {
        try await Task.sleep(nanoseconds: 150 * 1_000_000)
        return MockData.sampleUser
    }

    func fetchComments(postId: UUID) async throws -> [Comment] { try await Task.sleep(nanoseconds: 80 * 1_000_000); return MockData.makeComments(for: postId) }
    func createComment(postId: UUID, text: String) async throws -> Void { try await Task.sleep(nanoseconds: 80 * 1_000_000); return }
    func deleteComment(commentId: UUID) async throws -> Void { try await Task.sleep(nanoseconds: 60 * 1_000_000); return }
    func deletePost(_ postId: UUID) async throws -> Void { try await Task.sleep(nanoseconds: 120 * 1_000_000); return }
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

    private func debugLogRequest(_ req: URLRequest) {
        var out = "API Request -> "
        out += "\(req.httpMethod ?? "?") "
        out += "\(req.url?.absoluteString ?? "<no-url>")"
        if let headers = req.allHTTPHeaderFields, !headers.isEmpty { out += " headers:\(headers)" }
        if let body = req.httpBody, let s = String(data: body, encoding: .utf8) { out += " body:\(s)" }
        print(out)
    }

    func setAuthToken(_ token: String?) { self.authToken = token }

    func fetchPosts(page: Int, pageSize: Int) async throws -> [Post] {
        var comps = URLComponents(url: baseURL.appendingPathComponent("/posts"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [ URLQueryItem(name: "page", value: String(page)), URLQueryItem(name: "pageSize", value: String(pageSize)) ]
        var req = URLRequest(url: comps.url!)
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, _) = try await session.data(for: req)
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase; decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Post].self, from: data)
    }

    func createPost(authorId: UUID, imageData: Data?, caption: String?) async throws -> Post {
        let url = baseURL.appendingPathComponent("/posts")
        var req = URLRequest(url: url); req.httpMethod = "POST"
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        if let data = imageData {
            let boundary = "Boundary-\(UUID().uuidString)"
            req.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            var body = Data()
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"authorId\"\r\n\r\n")
            body.appendString("\(authorId.uuidString)\r\n")
            if let caption = caption {
                body.appendString("--\(boundary)\r\n")
                body.appendString("Content-Disposition: form-data; name=\"caption\"\r\n\r\n")
                body.appendString("\(caption)\r\n")
            }
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n")
            body.appendString("Content-Type: image/jpeg\r\n\r\n")
            body.append(data)
            body.appendString("\r\n--\(boundary)--\r\n")
            req.httpBody = body
        } else {
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
            var body: [String: Any] = [:]
            if let caption = caption { body["caption"] = caption }
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("createPost failed: HTTP \(http.statusCode) body: \(body)")
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase; decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Post.self, from: data)
    }

    func likePost(_ postId: UUID) async throws -> Int {
        let url = baseURL.appendingPathComponent("/posts/\(postId)/like")
        var req = URLRequest(url: url); req.httpMethod = "POST"
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("likePost failed HTTP \(http.statusCode): \(body)")
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let likes = decoded?["like_count"] as? Int { return likes }
        if let likes = decoded?["likes"] as? Int { return likes }
        throw URLError(.badServerResponse)
    }

    func unlikePost(_ postId: UUID) async throws -> Int {
        let url = baseURL.appendingPathComponent("/posts/\(postId)/like")
        var req = URLRequest(url: url); req.httpMethod = "DELETE"
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("unlikePost failed HTTP \(http.statusCode): \(body)")
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let likes = decoded?["like_count"] as? Int { return likes }
        if let likes = decoded?["likes"] as? Int { return likes }
        throw URLError(.badServerResponse)
    }

    func createSession(username: String, password: String) async throws -> (token: String, user: User) {
        let url = baseURL.appendingPathComponent("/sessions")
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["username": username, "password": password]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: req)
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase; decoder.dateDecodingStrategy = .iso8601
        let wrapperAny = try JSONSerialization.jsonObject(with: data)
        guard let wrapper = wrapperAny as? [String: Any], let token = wrapper["token"] as? String else { throw URLError(.badServerResponse) }
        if let userDict = wrapper["user"] as? [String: Any], let userData = try? JSONSerialization.data(withJSONObject: userDict) {
            let user = try decoder.decode(User.self, from: userData)
            return (token: token, user: user)
        }
        if let idStr = (wrapper["userId"] as? String) ?? (wrapper["user_id"] as? String) ?? (wrapper["id"] as? String) {
            if let uuid = UUID(uuidString: idStr) { return (token: token, user: User(id: uuid, username: "", displayName: nil, avatarURL: nil)) }
            return (token: token, user: User(id: UUID(), username: "", displayName: nil, avatarURL: nil))
        }
        throw URLError(.badServerResponse)
    }

    func createAccount(username: String, password: String, fullname: String?) async throws -> User {
        let url = baseURL.appendingPathComponent("/users")
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["username": username, "password": password]
        if let fullname = fullname { body["fullname"] = fullname }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("createAccount failed: HTTP \(http.statusCode) body: \(body)")
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase; decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(User.self, from: data)
    }

    func fetchComments(postId: UUID) async throws -> [Comment] {
        let url = baseURL.appendingPathComponent("/posts/")
            .appendingPathComponent(postId.uuidString)
            .appendingPathComponent("comments")
        var req = URLRequest(url: url)
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, _) = try await session.data(for: req)
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase; decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Comment].self, from: data)
    }

    func createComment(postId: UUID, text: String) async throws -> Void {
        let url = baseURL.appendingPathComponent("/comments")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        var comps = URLComponents()
        comps.queryItems = [ URLQueryItem(name: "operation", value: "create"), URLQueryItem(name: "postid", value: postId.uuidString), URLQueryItem(name: "text", value: text) ]
        req.httpBody = comps.percentEncodedQuery?.data(using: .utf8)
        req.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("createComment failed HTTP \(http.statusCode): \(body)")
            throw URLError(.badServerResponse)
        }
    }

    func deleteComment(commentId: UUID) async throws -> Void {
        let url = baseURL.appendingPathComponent("/comments")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        var comps = URLComponents()
        comps.queryItems = [ URLQueryItem(name: "operation", value: "delete"), URLQueryItem(name: "commentid", value: commentId.uuidString) ]
        req.httpBody = comps.percentEncodedQuery?.data(using: .utf8)
        req.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("deleteComment failed HTTP \(http.statusCode): \(body)")
            throw URLError(.badServerResponse)
        }
    }

    func deletePost(_ postId: UUID) async throws -> Void {
        let url = baseURL.appendingPathComponent("/posts/")
            .appendingPathComponent(postId.uuidString)
        var req = URLRequest(url: url); req.httpMethod = "DELETE"
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        _ = try await session.data(for: req)
    }
}

enum AppAPI {
    /// Default shared client. Swap to `RESTAPIClient(baseURL:)` when you have a backend.
    static var shared: APIClientProtocol = RESTAPIClient(baseURL: URL(string: "http://127.0.0.1:5001")!)
}

