import SwiftUI

@main
struct kiwifruitApp: App {
    // Shared stores injected into the SwiftUI environment so all views
    // observe the same source-of-truth instances.
    private let postsStore = PostsStore()
    private let sessionStore = SessionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.postsStore, postsStore)
                .environment(\.sessionStore, sessionStore)
        }
    }
}

// Removed debug-only MockAPIClient override so app uses REST client by default.
