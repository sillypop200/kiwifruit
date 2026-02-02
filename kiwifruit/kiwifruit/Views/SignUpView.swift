import SwiftUI

struct SignUpView: View {
    @Environment(\.sessionStore) private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var fullname: String = ""
    @State private var isLoading = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Username")) {
                    TextField("Username", text: $username).autocapitalization(.none)
                }
                Section(header: Text("Full name")) {
                    TextField("Full name", text: $fullname)
                }
                Section(header: Text("Password")) {
                    SecureField("Password", text: $password)
                }
            }
            .navigationTitle("Create Account")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading { ProgressView() } else {
                        Button("Create") { Task { await createAccount() } }
                            .disabled(username.isEmpty || password.isEmpty)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }

        .alert("Create Account Failed", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func createAccount() async {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await AppAPI.shared.createAccount(username: username, password: password, fullname: fullname.isEmpty ? nil : fullname)
            let (token, user) = try await AppAPI.shared.createSession(username: username, password: password)
            session.save(token: token, user: user)
            dismiss()
        } catch {
            print("Create account failed: \(error)")
            errorMessage = String(describing: error)
            showErrorAlert = true
        }
    }
}

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View { SignUpView() }
}
