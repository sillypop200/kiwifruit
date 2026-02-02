import SwiftUI
import PhotosUI

struct CreatePostView: View {
    @Environment(\.sessionStore) private var session: SessionStore
    @Environment(\.postsStore) private var postsStore: PostsStore
    @Binding var isPresented: Bool
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var caption: String = ""
    @State private var isSubmitting = false
    var onCreated: (Post) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Image")) {
                    PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                        HStack {
                            if let data = selectedImageData, let ui = UIImage(data: data) {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 120)
                                    .cornerRadius(8)
                            } else {
                                Label("Choose Photo", systemImage: "photo.on.rectangle")
                            }
                        }
                    }
                    .onChange(of: selectedItem) { newItem in
                        Task {
                            if let item = newItem {
                                if let data = try? await item.loadTransferable(type: Data.self) {
                                    selectedImageData = data
                                }
                            }
                        }
                    }
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
                        .disabled(selectedImageData == nil || session.userId == nil)
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }

    private func submit() async {
        guard let userId = session.userId else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
              let created = try await APIClient.shared.createPost(authorId: userId, imageData: selectedImageData, caption: caption.isEmpty ? nil : caption)
              postsStore.prepend(created)
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
