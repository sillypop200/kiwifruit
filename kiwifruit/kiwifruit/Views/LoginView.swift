import SwiftUI

struct LoginView: View {
    @Environment(\.sessionStore) private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isLoading = false
    @State private var showingSignUp = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Username")) {
                    TextField("Enter username", text: $username)
                        .autocapitalization(.none)
                }
                Section(header: Text("Password")) {
                    SecureField("Password", text: $password)
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
                        .disabled(username.isEmpty || password.isEmpty)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Create Account") { showingSignUp = true }
                }
            }
            .sheet(isPresented: $showingSignUp) { SignUpView() }
        }
    }

    private func signIn() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let (token, user) = try await AppAPI.shared.createSession(username: username, password: password)
            session.save(token: token, user: user)
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
