import SwiftUI

struct FeedView: View {
    @State private var vm = FeedViewModel()
    @State private var showingCreate = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(vm.posts) { post in
                    PostRow(post: post)
                        .onAppear {
                            Task { await vm.fetchNextIfNeeded(currentPost: post) }
                        }
                        .padding(.horizontal)
                }

                if vm.isLoading {
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
            await vm.loadInitial()
        }
        .sheet(isPresented: $showingCreate) {
            CreatePostView(isPresented: $showingCreate) { post in
                vm.prepend(post)
            }
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
