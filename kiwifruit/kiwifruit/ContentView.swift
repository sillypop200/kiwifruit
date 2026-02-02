//
//  ContentView.swift
//  kiwifruit
//
//  Created by Bonnie Huynh on 2026-01-29.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                FeedView()
            }
            .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack {
                ProfileView(user: MockData.sampleUser)
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }

            NavigationStack {
                Text("Challenges coming soon")
                    .foregroundColor(.secondary)
            }
            .tabItem { Label("Challenges", systemImage: "flag") }

            NavigationStack {
                Text("Focus timer")
                    .foregroundColor(.secondary)
            }
            .tabItem { Label("Focus", systemImage: "timer") }
        }
        .tint(.green)
        .environment(\.likesStore, LikesStore())
        .environment(\.sessionStore, SessionStore())
        .environment(\.postsStore, PostsStore())
    }
}

#Preview {
    ContentView()
}
