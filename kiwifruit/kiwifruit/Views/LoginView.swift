import SwiftUI

struct LoginView: View {
    @Environment(\.sessionStore) private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isLoading = false
    @State private var showingSignUp = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

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
            .alert("Sign In Failed", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func signIn() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let (token, user) = try await AppAPI.shared.createSession(username: username, password: password)
            session.save(token: token, user: user)
            print("LoginView.signIn: signed in user=\(user.username) token=\(token.prefix(8))..")
            dismiss()
        } catch {
            print("Sign in failed: \(error)")
            errorMessage = String(describing: error)
            showErrorAlert = true
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
