import Foundation
import Observation

@Observable
final class LikesStore {
    private(set) var likedIDs: Set<String> = []

    private let key = "kiwifruit.likedIDs"

    init() {
        load()
    }

    func isLiked(_ post: Post) -> Bool {
        likedIDs.contains(post.id)
    }

    func toggle(_ post: Post) {
        if likedIDs.contains(post.id) {
            likedIDs.remove(post.id)
        } else {
            likedIDs.insert(post.id)
        }
        save()
    }

    private func save() {
        let arr = Array(likedIDs)
        UserDefaults.standard.set(arr, forKey: key)
    }

    private func load() {
        guard let arr = UserDefaults.standard.array(forKey: key) as? [String] else { return }
        likedIDs = Set(arr)
    }
}

// Environment key to provide LikesStore via SwiftUI environment
import SwiftUI

private struct LikesStoreKey: EnvironmentKey {
    static let defaultValue: LikesStore = LikesStore()
}

extension EnvironmentValues {
    var likesStore: LikesStore {
        get { self[LikesStoreKey.self] }
        set { self[LikesStoreKey.self] = newValue }
    }
}
