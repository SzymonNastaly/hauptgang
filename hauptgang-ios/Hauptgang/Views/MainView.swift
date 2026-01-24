import SwiftUI

/// Hides toolbar background on iOS 18+ to avoid Liquid Glass effect
struct HiddenToolbarBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        } else {
            content
        }
    }
}

struct MainView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showingLogoutConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.hauptgangBackground
                    .ignoresSafeArea()

                VStack(spacing: Theme.Spacing.xl) {
                    Spacer()

                    // Welcome section
                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 60))
                            .foregroundColor(.hauptgangPrimary)

                        Text("Welcome!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.hauptgangTextPrimary)

                        if let user = authManager.authState.user {
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundColor(.hauptgangTextSecondary)
                        }
                    }

                    Spacer()

                    // User info card
                    if let user = authManager.authState.user {
                        VStack(spacing: Theme.Spacing.md) {
                            HStack {
                                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                    Text("Signed in as")
                                        .font(.caption)
                                        .foregroundColor(.hauptgangTextMuted)
                                    Text(user.email)
                                        .font(.body)
                                        .foregroundColor(.hauptgangTextPrimary)
                                }

                                Spacer()

                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.hauptgangSuccess)
                            }
                        }
                        .padding(Theme.Spacing.lg)
                        .background(Color.hauptgangCard)
                        .cornerRadius(Theme.CornerRadius.lg)
                        .shadow(
                            color: Theme.Shadow.sm.color,
                            radius: Theme.Shadow.sm.radius,
                            y: Theme.Shadow.sm.y
                        )
                        .padding(.horizontal, Theme.Spacing.lg)
                    }

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingLogoutConfirmation = true
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(Color.hauptgangPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .modifier(HiddenToolbarBackgroundModifier())
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
    return MainView()
        .environmentObject(authManager)
        .onAppear {
            // Simulate authenticated state for preview
            authManager.signIn(user: User(id: 1, email: "test@example.com"))
        }
}
