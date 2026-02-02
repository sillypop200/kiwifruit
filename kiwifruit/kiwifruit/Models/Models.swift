import Foundation
import SwiftUI

struct User: Identifiable, Codable, Hashable {
    let id: UUID
    let username: String
    let displayName: String?
    let avatarURL: URL?
}

struct Post: Identifiable, Codable, Hashable {
    let id: UUID
    let author: User
    let imageURL: URL
    let caption: String?
    var likes: Int
    let createdAt: Date
}

struct Comment: Identifiable, Codable, Hashable {
    let id: UUID
    let postId: UUID
    let author: User
    let text: String
    let createdAt: Date
}
