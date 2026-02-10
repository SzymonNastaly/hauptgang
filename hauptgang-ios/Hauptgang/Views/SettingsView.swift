import RevenueCatUI
import SwiftUI

/// Settings screen with user info and sign out
struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showingLogoutConfirmation = false
    @State private var showingPaywall = false
    @State private var showingCustomerCenter = false

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

                // Subscription section
                Section("Subscription") {
                    if subscriptionManager.isPro {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                            Text("Hauptgang Pro")
                                .fontWeight(.semibold)
                        }
                        Button {
                            showingCustomerCenter = true
                        } label: {
                            HStack {
                                Image(systemName: "gearshape")
                                Text("Manage Subscription")
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "person")
                                .foregroundColor(.hauptgangTextSecondary)
                            Text("Free Plan")
                        }
                        Button {
                            showingPaywall = true
                        } label: {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("Upgrade to Pro")
                            }
                        }
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
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showingCustomerCenter) {
                CustomerCenterView()
            }
        }
    }
}

#Preview {
    let authManager = AuthManager()
    let subscriptionManager = SubscriptionManager()
    return SettingsView()
        .environmentObject(authManager)
        .environmentObject(subscriptionManager)
        .onAppear {
            authManager.signIn(user: User(id: 1, email: "test@example.com"))
        }
}
