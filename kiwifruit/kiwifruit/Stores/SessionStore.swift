import Foundation
import Observation
import SwiftUI

@Observable
final class SessionStore {
    private let tokenKey = "kiwifruit.session.token"
    private let userKey = "kiwifruit.session.userId"

    private(set) var token: String? = nil
    private(set) var userId: UUID? = nil

    let apiClient: RESTAPIClient

    init(baseURL: URL = URL(string: "https://api.kiwifruit.example.com")!) {
        self.apiClient = RESTAPIClient(baseURL: baseURL)
        load()
        // Ensure global API client uses this REST client by default
        APIClient.shared = apiClient
        apiClient.setAuthToken(token)
    }

    func save(token: String, userId: UUID?) {
        self.token = token
        self.userId = userId
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(userId?.uuidString, forKey: userKey)
        apiClient.setAuthToken(token)
        APIClient.shared = apiClient
    }

    func clear() {
        token = nil
        userId = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        apiClient.setAuthToken(nil)
        APIClient.shared = MockAPIClient()
    }

    private func load() {
        if let token = UserDefaults.standard.string(forKey: tokenKey) {
            self.token = token
        }
        if let userIdStr = UserDefaults.standard.string(forKey: userKey), let uuid = UUID(uuidString: userIdStr) {
            self.userId = uuid
        }
    }
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
