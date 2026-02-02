import Foundation
import Observation
import SwiftUI

@Observable
final class SessionStore {
    private let tokenKey = "kiwifruit.session.token"
    private let userKey = "kiwifruit.session.userId"
    private let userJSONKey = "kiwifruit.session.user"
    

    private(set) var token: String? = nil
    private(set) var userId: String? = nil
    private(set) var currentUser: User? = nil
    // Whether the saved token/session has been validated against the server
    private(set) var isValidSession: Bool = false
    // (no forced-login flag)

    let apiClient: RESTAPIClient

    // Default to local dev server. Change `baseURL` when pointing to a deployed API.
    // If your Flask server runs on a different port (e.g. 50001), set that here
    // or set the `KIWIFRUIT_API_URL` env var and pass it when creating the store.
    init(baseURL: URL = URL(string: "http://127.0.0.1:5001")!) {
        self.apiClient = RESTAPIClient(baseURL: baseURL)
        load()
        // Ensure global API client uses this REST client by default
        AppAPI.shared = apiClient
        apiClient.setAuthToken(token)
        // If we have a token and userId loaded, asynchronously validate that the token is still valid
        if let token = token, let userId = userId {
            Task {
                do {
                    let user = try await fetchUser(id: userId)
                    DispatchQueue.main.async {
                        self.currentUser = user
                        self.isValidSession = true
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.clear()
                    }
                }
            }
        }
    }

    func save(token: String, user: User?) {
        self.token = token
        self.currentUser = user
        self.userId = user?.id
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(user?.id, forKey: userKey)
        if let user = user, let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userJSONKey)
        } else {
            UserDefaults.standard.removeObject(forKey: userJSONKey)
        }
        apiClient.setAuthToken(token)
        AppAPI.shared = apiClient
        isValidSession = true
        print("SessionStore.save: saved token=\(token.prefix(8)).. userId=\(user?.id ?? "<nil>") username=\(user?.username ?? "<nil>")")
    }

    func clear() {
        token = nil
        userId = nil
        currentUser = nil
        isValidSession = false
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        UserDefaults.standard.removeObject(forKey: userJSONKey)
        apiClient.setAuthToken(nil)
        // Keep the REST client as the shared API so login/sign-up still talk to the backend.
        AppAPI.shared = apiClient
        print("SessionStore.clear: cleared session")
    }

    private func load() {
        if let token = UserDefaults.standard.string(forKey: tokenKey) {
            self.token = token
        }
        if let userIdStr = UserDefaults.standard.string(forKey: userKey) {
            self.userId = userIdStr
        }
        if let data = UserDefaults.standard.data(forKey: userJSONKey) {
            if let user = try? JSONDecoder().decode(User.self, from: data) {
                self.currentUser = user
            }
        }
        print("SessionStore.load: token=\(token != nil ? "present" : "nil") userId=\(userId ?? "nil") currentUser=\(currentUser?.username ?? "nil")")
    }

    // Fetch a user by id (string) using the REST client; throws on network or decode errors
    private func fetchUser(id: String) async throws -> User {
        let url = apiClient.baseURL.appendingPathComponent("/users/")
            .appendingPathComponent(id)
        var req = URLRequest(url: url)
        if let token = token { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, _) = try await apiClient.session.data(for: req)
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase; decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(User.self, from: data)
    }

    // removed force-fresh-login API
}

// Environment key for SessionStore
private struct SessionStoreKey: EnvironmentKey {
    static let defaultValue: SessionStore = SessionStore()
}

extension EnvironmentValues {
    var sessionStore: SessionStore {
        get { self[SessionStoreKey.self] }
        set { self[SessionStoreKey.self] = newValue }
    }
}
