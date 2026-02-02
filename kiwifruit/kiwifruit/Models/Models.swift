import Foundation
import SwiftUI

struct User: Identifiable, Codable, Hashable {
    let id: String
    let username: String
    let displayName: String?
    let avatarURL: URL?
}

struct Post: Identifiable, Codable, Hashable {
    let id: String
    let author: User
    let imageURL: URL
    let caption: String?
    var likes: Int
    let createdAt: Date?
    // Optional fields returned by the server for the MVP shape
    var commentCount: Int?
    var likedByMe: Bool?
}

struct Comment: Identifiable, Codable, Hashable {
    let id: String
    // Server responses may omit postId; make optional to be tolerant
    let postId: String?
    let author: User
    let text: String
    let createdAt: Date
}
