import SwiftUI

struct LoginView: View {
    @Environment(\.sessionStore) private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var username: String = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Username")) {
                    TextField("Enter username", text: $username)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("Sign In")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button("Sign In") {
                            Task { await signIn() }
                        }
                        .disabled(username.isEmpty)
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func signIn() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let (token, userId) = try await APIClient.shared.createSession(username: username)
            session.save(token: token, userId: userId)
            dismiss()
        } catch {
            print("Sign in failed: \(error)")
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
