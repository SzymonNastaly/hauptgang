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
                self.userSection
                self.cookbookSection
                self.subscriptionSection
                self.accountActionsSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog(
                "Sign out?",
                isPresented: self.$showingLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign out", role: .destructive) {
                    Task { await self.authManager.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need to sign in again to access your account.")
            }
            .sheet(isPresented: self.$showingPaywall) {
                PaywallView()
            }
            .sheet(isPresented: self.$showingCustomerCenter) {
                CustomerCenterView()
            }
        }
    }

    @ViewBuilder
    private var userSection: some View {
        if let user = self.authManager.authState.user {
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
    }

    private var cookbookSection: some View {
        Section("Cookbooks") {
            NavigationLink {
                CookbookSettingsView()
            } label: {
                HStack {
                    Image(systemName: "book.closed.fill")
                        .foregroundColor(.hauptgangPrimary)
                    Text("Manage Cookbooks")
                }
            }
        }
    }

    private var subscriptionSection: some View {
        Section("Subscription") {
            if self.subscriptionManager.isPro {
                self.proSubscriptionContent
            } else {
                self.freeSubscriptionContent
            }
        }
    }

    private var proSubscriptionContent: some View {
        Group {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
                Text("Hauptgang Pro")
                    .fontWeight(.semibold)
            }
            Button {
                self.showingCustomerCenter = true
            } label: {
                HStack {
                    Image(systemName: "gearshape")
                    Text("Manage Subscription")
                }
            }
        }
    }

    private var freeSubscriptionContent: some View {
        Group {
            HStack {
                Image(systemName: "person")
                    .foregroundColor(.hauptgangTextSecondary)
                Text("Free Plan")
            }
            Button {
                self.showingPaywall = true
            } label: {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("Upgrade to Pro")
                }
            }
        }
    }

    private var accountActionsSection: some View {
        Section {
            Button(role: .destructive) {
                self.showingLogoutConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                }
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
