import SwiftUI

struct CreatePostView: View {
    @Environment(\.sessionStore) private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    @State private var imageURLText: String = ""
    @State private var caption: String = ""
    @State private var isSubmitting = false
    var onCreated: (Post) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Image")) {
                    TextField("Image URL", text: $imageURLText)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }

                Section(header: Text("Caption")) {
                    TextEditor(text: $caption)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("New Reflection")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Post") {
                            Task { await submit() }
                        }
                        .disabled(imageURLText.isEmpty)
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }

    private func submit() async {
        guard let url = URL(string: imageURLText) else { return }
        guard let userId = session.userId else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let created = try await APIClient.shared.createPost(authorId: userId, imageURL: url, caption: caption.isEmpty ? nil : caption)
            onCreated(created)
            isPresented = false
        } catch {
            print("Failed to create post: \(error)")
        }
    }
}

struct CreatePostView_Previews: PreviewProvider {
    static var previews: some View {
        CreatePostView(isPresented: .constant(true)) { _ in }
    }
}
