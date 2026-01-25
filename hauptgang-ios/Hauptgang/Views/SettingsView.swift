import SwiftUI

/// Settings screen with user info and sign out
struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showingLogoutConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                // User info section
                if let user = authManager.authState.user {
                    Section {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title)
                                .foregroundColor(.hauptgangPrimary)

                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text("Signed in as")
                                    .font(.caption)
                                    .foregroundColor(.hauptgangTextSecondary)
                                Text(user.email)
                                    .font(.body)
                                    .foregroundColor(.hauptgangTextPrimary)
                            }
                        }
                        .padding(.vertical, Theme.Spacing.xs)
                    }
                }

                // Account actions section
                Section {
                    Button(role: .destructive) {
                        showingLogoutConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog(
                "Sign out?",
                isPresented: $showingLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign out", role: .destructive) {
                    Task {
                        await authManager.signOut()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need to sign in again to access your account.")
            }
        }
    }   
}

#Preview {
    let authManager = AuthManager()
    return SettingsView()
        .environmentObject(authManager)
        .onAppear {
            authManager.signIn(user: User(id: 1, email: "test@example.com"))
        }
}
