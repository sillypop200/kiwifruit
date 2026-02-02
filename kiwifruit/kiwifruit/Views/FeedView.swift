import SwiftUI

struct FeedView: View {
    @Environment(\.postsStore) private var store: PostsStore
    @State private var showingCreate = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(store.posts) { post in
                    PostRow(post: post)
                        .onAppear {
                            Task { if post == store.posts.last { await store.fetchNext() } }
                        }
                        .padding(.horizontal)
                }

                if store.isLoading {
                    ProgressView()
                        .padding()
                }
            }
            .padding(.top)
        }
        .navigationTitle("Kiwis")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingCreate = true }) {
                    Image(systemName: "plus.app")
                }
            }
        }
        .task {
            await store.loadInitial()
        }
        .sheet(isPresented: $showingCreate) {
            CreatePostView(isPresented: $showingCreate) { post in
                store.prepend(post)
            }
            .environment(\.postsStore, store)
        }
    }
}

struct FeedView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            FeedView()
        }
    }
}
