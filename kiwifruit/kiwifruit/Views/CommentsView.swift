import SwiftUI

struct CommentsView: View {
    let post: Post
    @Environment(\.commentsStore) private var commentsStore: CommentsStore
    @Environment(\.sessionStore) private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var newCommentText: String = ""

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    ForEach(commentsStore.comments(for: post)) { c in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(c.author.displayName ?? c.author.username)
                                .font(.subheadline)
                                .bold()
                            Text(c.text)
                                .font(.body)
                            Text(c.createdAt, style: .time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }

                HStack {
                    TextField("Add a comment...", text: $newCommentText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Send") { Task { await addComment() } }
                        .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.userId == nil)
                }
                .padding()
            }
            .navigationTitle("Comments")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .task { await commentsStore.fetchForPost(post) }
        }
    }

    private func addComment() async {
        guard let uid = session.userId else { return }
        await commentsStore.createComment(newCommentText, post: post, author: MockData.sampleUser)
        newCommentText = ""
    }
}

struct CommentsView_Previews: PreviewProvider {
    static var previews: some View {
        CommentsView(post: MockData.makePosts(count: 1, page: 0).first!)
    }
}
