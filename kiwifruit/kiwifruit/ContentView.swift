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
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            NavigationStack {
                ProfileView(user: MockData.sampleUser)
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }
        }
        .accentColor(.green)
        .environment(\.likesStore, LikesStore())
        .environment(\.sessionStore, SessionStore())
    }
}

#Preview {
    ContentView()
}
